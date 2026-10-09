const builtin = @import("builtin");

/// Performs a runtime assertion on a constant time condition. Will always perform
/// runtime assertions regardless of build mode *(i.e. runs on `Debug`, `ReleaseSafe`,
/// `ReleaseFast`, and `ReleaseSmall`)*
pub fn cheap(ok: bool) void {
    @disableInstrumentation();
    if (!ok) fail();
}

/// Performs a runtime assertion on a non-constant time condition or on an expensive
/// callback. Will only perform runtime assertions on `Debug` and `ReleaseSafe` build
/// modes.
pub fn expensive(comptime check_fn: anytype, args: anytype) void {
    @disableInstrumentation();
    if (builtin.mode == .Debug) {
        if (!@call(.auto, check_fn, args)) fail();
    }
}

/// Wrapper for panic and also informs the compiler to actively not optimize this
/// branch since this execution branch is not expected to run multiple times during the
/// program's lifetime.
fn fail() noreturn {
    @branchHint(.cold);
    @panic("assertion failed");
}
