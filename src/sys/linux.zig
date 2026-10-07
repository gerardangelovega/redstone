// standard library, library, and module imports
const std = @import("std");

// aliases
const linux = std.os.linux;
const log = std.log.scoped(.sys_linux);

const SocketError = error{
    ProcessFdLimitExceeded,
    SystemFdLimitExceeded,
    SystemResourcesExhausted,
    Unexpected,
};
/// Wrapper around the `socket()` syscall for more erogonomic and convenient
/// handling of errors and return values.
///
/// Returns an `i32` value representing an fd.
pub fn socket(domain: u32, socket_type: u32, protocol: u32) SocketError!i32 {
    const ret: usize = linux.socket(domain, socket_type, protocol);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return @intCast(ret);
        },
        .MFILE => {
            return error.ProcessFdLimitExceeded;
        },
        .NFILE => {
            return error.SystemFdLimitExceeded;
        },
        .NOBUFS, .NOMEM => {
            return error.SystemResourcesExhausted;
        },
        else => |errno| {
            log.err(
                "socket() syscall failed: errno={s}",
                .{@tagName(errno)},
            );
            return error.Unexpected;
        },
    }
}

const SetSockOptError = error{
    Unexpected,
};
/// Wrapper around the `setsockopt()` syscall for more erogonomic and convenient
/// handling of errors and to provide a simpler interface for the syscall.
pub fn setsockopt(fd: i32, level: i32, optname: u32, val: u32) SetSockOptError!void {
    const optval = &std.mem.toBytes(val);
    const ret: usize = linux.setsockopt(fd, level, optname, optval, optval.len);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return;
        },
        else => |errno| {
            log.err(
                "setsockopt() syscall failed: fd={d} errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

const FcntlError = error{
    Unexpected,
};
/// Wrapper around the `fcntl()` syscall for more erogonomic and convenient handling of
/// errors and return values.
///
/// Returns a `u32` value that may represent status code or fd flags.
pub fn fcntl(fd: i32, cmd: i32, arg: usize) FcntlError!u32 {
    const ret: usize = linux.fcntl(fd, cmd, arg);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return @intCast(ret);
        },
        else => |errno| {
            log.err(
                "fcntl() syscall failed: fd={d}, errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

const BindError = error{
    PermissionDenied,
    AddressInUse,
    AddressNotAvailable,
    Unexpected,
};
/// Wrapper around the `bind()` syscall for more erogonomic and convenient handling
/// of errors.
pub fn bind(fd: i32, addr: *const linux.sockaddr.in) BindError!void {
    const ret: usize = linux.bind(fd, @ptrCast(addr), @sizeOf(linux.sockaddr.in));
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return;
        },
        .ACCES => {
            return error.PermissionDenied;
        },
        .ADDRINUSE => {
            return error.AddressInUse;
        },
        .ADDRNOTAVAIL => {
            return error.AddressNotAvailable;
        },
        else => |errno| {
            log.err(
                "bind() syscall failed: fd={d} errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

const ListenError = error{
    AddressInUse,
    Unexpected,
};
/// Wrapper around the `listen()` syscall for more erogonomic and convenient handling
/// of errors.
pub fn listen(fd: i32, backlog: u32) ListenError!void {
    const ret: usize = linux.listen(fd, backlog);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return;
        },
        .ADDRINUSE => {
            return error.AddressInUse;
        },
        else => |errno| {
            log.err(
                "listen() syscall failed: fd={d} errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

const AcceptError = error{
    Interrupted,
    WouldBlock,
    ConnectionAborted,
    ProcessFdLimitExceeded,
    SystemFdLimitExceeded,
    SystemResourcesExhausted,
    Unexpected,
};
/// Wrapper around the `accept()` syscall for more erogonomic and convenient
/// handling of errors and to provide a simpler interface for the syscall.
///
/// Returns an `i32` value representing an fd.
pub fn accept(fd: i32, addr: ?*linux.sockaddr) AcceptError!i32 {
    var len: u32 = if (addr != null) @sizeOf(linux.sockaddr) else 0;
    const len_ptr: ?*u32 = if (addr != null) &len else null;

    const ret: usize = linux.accept(fd, addr, len_ptr);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return @intCast(ret);
        },
        .INTR => {
            return error.Interrupted;
        },
        .AGAIN => {
            return error.WouldBlock;
        },
        .CONNABORTED => {
            return error.ConnectionAborted;
        },
        .MFILE => {
            return error.ProcessFdLimitExceeded;
        },
        .NFILE => {
            return error.SystemFdLimitExceeded;
        },
        .NOBUFS, .NOMEM => {
            return error.SystemResourcesExhausted;
        },
        else => |errno| {
            log.err(
                "accept() syscall failed: fd={d}, errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

// TODO2: implement accept4() syscall wrapper and replace accept() usage with accept4()

// TODO2: document purpose of function
// TODO2: move Unexpected inside of error set
const ConnectError = error{
    Unexpected,
};
// TODO2: implement connect() syscall wrapper function

const ReadError = error{
    EndOfStream,
    WouldBlock,
    Interrupted,
    ConnectionResetByPeer,
    Unexpected,
};
/// Wrapper around the `read()` syscall for more erogonomic and convenient
/// handling of errors and return values.
///
/// Returns a `usize` value that can be used for indexing or slicing
pub fn read(fd: i32, buf: [*]u8, count: usize) ReadError!usize {
    const ret: usize = linux.read(fd, buf, count);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            if (ret == 0) return error.EndOfStream;
            return ret;
        },
        .AGAIN => {
            return error.WouldBlock;
        },
        .INTR => {
            return error.Interrupted;
        },
        .CONNRESET => {
            return error.ConnectionResetByPeer;
        },
        else => |errno| {
            log.err(
                "read() syscall failed: fd={d} errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

const WriteError = error{
    WouldBlock,
    Interrupted,
    BrokenPipe,
    ConnectionResetByPeer,
    Unexpected,
};
/// Wrapper around the `write()` syscall for more erogonomic and convenient
/// handling of errors and return values.
///
/// Returns a `usize` value that can be used for indexing or slicing
pub fn write(fd: i32, buf: [*]const u8, count: usize) WriteError!usize {
    const ret: usize = linux.write(fd, buf, count);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return ret;
        },
        .AGAIN => {
            return error.WouldBlock;
        },
        .INTR => {
            return error.Interrupted;
        },
        .PIPE => {
            return error.BrokenPipe;
        },
        .CONNRESET => {
            return error.ConnectionResetByPeer;
        },
        else => |errno| {
            log.err(
                "write() syscall failed: fd={d} errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

// TODO2: Implement recv() syscall wrapper and replace read() usage with recv()
// TODO2: Implement send() syscall wrapper and replace write() usage with send()

const EpollCreate1Error = error{
    ProcessFdLimitExceeded,
    SystemFdLimitExceeded,
    SystemResourcesExhausted,
    Unexpected,
};
/// Wrapper around the `epoll_create1()` syscall for more erogonomic and convenient
/// handling of errors and return values.
///
/// Returns an `i32` value representing an fd.
pub fn epoll_create1(flags: usize) EpollCreate1Error!i32 {
    const ret: usize = linux.epoll_create1(flags);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return @intCast(ret);
        },
        .MFILE => {
            return error.ProcessFdLimitExceeded;
        },
        .NFILE => {
            return error.SystemFdLimitExceeded;
        },
        .NOMEM => {
            return error.SystemResourcesExhausted;
        },
        else => |errno| {
            log.err(
                "epoll_create1() syscall failed: errno={s}",
                .{@tagName(errno)},
            );
            return error.Unexpected;
        },
    }
}

const EpollWaitError = error{
    Interrupted,
    Unexpected,
};
/// Wrapper around the `epoll_wait()` syscall for more erogonomic and convenient
/// handling of errors and return values.
///
/// Returns a `usize` value that can be used for indexing or slicing.
pub fn epoll_wait(
    epoll_fd: i32,
    events: [*]linux.epoll_event,
    maxevents: u32,
    timeout: i32,
) EpollWaitError!usize {
    const ret: usize = linux.epoll_wait(epoll_fd, events, maxevents, timeout);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return ret;
        },
        .INTR => {
            return error.Interrupted;
        },
        else => |errno| {
            log.err(
                "epoll_wait() syscall failed: fd={d} errno={s}",
                .{ epoll_fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

const EpollCtlError = error{
    SystemResourcesExhausted,
    EpollUserWatchLimitExceeded,
    Unexpected,
};
/// Wrapper around the `epoll_ctl()` syscall for more erogonomic and convenient
/// handling of errors.
pub fn epoll_ctl(
    epoll_fd: i32,
    op: u32,
    fd: i32,
    ev: ?*linux.epoll_event,
) EpollCtlError!void {
    const ret: usize = linux.epoll_ctl(epoll_fd, op, fd, ev);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return;
        },
        .NOMEM => {
            return error.SystemResourcesExhausted;
        },
        .NOSPC => {
            return error.EpollUserWatchLimitExceeded;
        },
        else => |errno| {
            log.err(
                "epoll_ctl() syscall failed: fd={d} errno={s}",
                .{ epoll_fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

const CloseError = error{
    Interrupted,
    Unexpected,
};
/// Wrapper around the `close()` syscall for more erogonomic and convenient
/// handling of errors.
pub fn close(fd: i32) CloseError!void {
    const ret: usize = linux.close(fd);
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return;
        },
        .INTR => {
            return error.Interrupted;
        },
        else => |errno| {
            log.err(
                "close() syscall failed: fd={d} errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}
