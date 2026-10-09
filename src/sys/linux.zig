// standard library, library, and module imports
const std = @import("std");

// aliases
const assert = @import("assert");
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
    assert.cheap(fd >= 0);
    assert.cheap(level >= 0);

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
    assert.cheap(fd >= 0);
    assert.cheap(cmd >= 0);

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
    assert.cheap(fd >= 0);

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
    assert.cheap(fd >= 0);

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
/// handling of errors and return values, and to provide a simpler interface for the
/// syscall.
///
/// Returns an `i32` value representing an fd.
pub fn accept(fd: i32, addr: ?*linux.sockaddr) AcceptError!i32 {
    assert.cheap(fd >= 0);

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

const Accept4Error = AcceptError;
/// Wrapper around the `accept4()` syscall for more erogonomic and convenient
/// handling of errors and return values, and to provide a simpler interface for the
/// syscall.
///
/// Returns an `i32` value representing an fd.
pub fn accept4(fd: i32, addr: ?*linux.sockaddr, flags: u32) Accept4Error!i32 {
    assert.cheap(fd >= 0);

    var len: u32 = if (addr != null) @sizeOf(linux.sockaddr) else 0;
    const len_ptr: ?*u32 = if (addr != null) &len else null;

    const ret: usize = linux.accept4(fd, addr, len_ptr, flags);
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
                "accept4() syscall failed: fd={d}, errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

const ConnectError = error{
    Interrupted,
    WouldBlock,
    PermissionDenied,
    AddressInUse,
    AddressNotAvailable,
    ConnectionRefusedByPeer,
    ConnectionPending,
    ConnectedAlready,
    ConnectionTimedOut,
    NetworkUnreachable,
    Unexpected,
};
/// Wrapper around the `connect()` syscall for more erogonomic and convenient
/// handling of errors and return values, and to provide a simpler interface for the
/// syscall.
pub fn connect(fd: i32, addr: *const linux.sockaddr.in) ConnectError!void {
    assert.cheap(fd >= 0);

    const ret: usize = linux.connect(fd, @ptrCast(addr), @sizeOf(linux.sockaddr.in));
    switch (linux.errno(ret)) {
        .SUCCESS => {
            return;
        },
        .INTR => {
            return error.Interrupted;
        },
        .AGAIN => {
            return error.WouldBlock;
        },
        .ACCES, .PERM => {
            return error.PermissionDenied;
        },
        .ADDRINUSE => {
            return error.AddressInUse;
        },
        .ADDRNOTAVAIL => {
            return error.AddressNotAvailable;
        },
        .CONNREFUSED => {
            return error.ConnectionRefusedByPeer;
        },
        .ALREADY, .INPROGRESS => {
            return error.ConnectionPending;
        },
        .ISCONN => {
            return error.ConnectedAlready;
        },
        .TIMEDOUT => {
            return error.ConnectionTimedOut;
        },
        .NETUNREACH => {
            return error.NetworkUnreachable;
        },
        else => |errno| {
            log.err(
                "connect() syscall failed: fd={d} errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

const ReadError = error{
    EndOfStream,
    WouldBlock,
    Interrupted,
    Unexpected,
};
/// Wrapper around the `read()` syscall for more erogonomic and convenient
/// handling of errors and return values.
///
/// Returns a `usize` value that can be used for indexing or slicing
pub fn read(fd: i32, buffer_out: []u8) ReadError!usize {
    assert.cheap(fd >= 0);
    assert.cheap(buffer_out.len > 0);

    const ret: usize = linux.read(fd, buffer_out.ptr, buffer_out.len);
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
    Unexpected,
};
/// Wrapper around the `write()` syscall for more erogonomic and convenient
/// handling of errors and return values.
///
/// Returns a `usize` value that can be used for indexing or slicing
pub fn write(fd: i32, buffer_in: []const u8) WriteError!usize {
    assert.cheap(fd >= 0);
    assert.cheap(buffer_in.len > 0);

    const ret: usize = linux.write(fd, buffer_in.ptr, buffer_in.len);
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
        else => |errno| {
            log.err(
                "write() syscall failed: fd={d} errno={s}",
                .{ fd, @tagName(errno) },
            );
            return error.Unexpected;
        },
    }
}

const RecvError = error{
    EndOfStream,
    WouldBlock,
    Interrupted,
    SystemResourcesExhausted,
    ConnectionResetByPeer,
    ConnectionRefusedByPeer,
    Unexpected,
};
/// Wrapper around the `recv()` syscall for more erogonomic and convenient
/// handling of errors and return values.
///
/// Returns a `usize` value that can be used for indexing or slicing
pub fn recv(fd: i32, buffer_out: []u8, flags: u32) RecvError!usize {
    assert.cheap(fd >= 0);
    assert.cheap(buffer_out.len > 0);

    const ret: usize = linux.recvfrom(
        fd,
        buffer_out.ptr,
        buffer_out.len,
        flags,
        null,
        null,
    );
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
        .NOMEM => {
            return error.SystemResourcesExhausted;
        },
        .CONNRESET => {
            return error.ConnectionResetByPeer;
        },
        .CONNREFUSED => {
            return error.ConnectionRefusedByPeer;
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

const SendError = error{
    WouldBlock,
    Interrupted,
    SystemResourcesExhausted,
    BrokenPipe,
    ConnectionResetByPeer,
    ConnectionRefusedByPeer,
    Unexpected,
};
/// Wrapper around the `send()` syscall for more erogonomic and convenient
/// handling of errors and return values.
///
/// Returns a `usize` value that can be used for indexing or slicing
pub fn send(fd: i32, buffer_in: []const u8, flags: u32) SendError!usize {
    assert.cheap(fd >= 0);
    assert.cheap(buffer_in.len > 0);

    const ret: usize = linux.sendto(
        fd,
        buffer_in.ptr,
        buffer_in.len,
        flags,
        null,
        0,
    );
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
        .NOMEM => {
            return error.SystemResourcesExhausted;
        },
        .CONNRESET => {
            return error.ConnectionResetByPeer;
        },
        .CONNREFUSED => {
            return error.ConnectionRefusedByPeer;
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
    assert.cheap(epoll_fd >= 0);

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
    assert.cheap(epoll_fd >= 0);
    assert.cheap(fd >= 0);
    assert.cheap(epoll_fd != fd);
    if (op == linux.EPOLL.CTL_ADD) assert.cheap(ev != null);
    if (op == linux.EPOLL.CTL_MOD) assert.cheap(ev != null);

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
    assert.cheap(fd >= 0);

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
