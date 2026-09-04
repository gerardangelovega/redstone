const std = @import("std");

const zcc = @import("compile_commands.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "redstone",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    exe.root_module.addCSourceFiles(.{
        .files = &.{
            "src/main.cpp",
        },
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-Wpedantic",
            "-Werror",
            "-std=c++17"
        }
    });

    b.installArtifact(exe);

    var targets: std.ArrayList(*std.Build.Step.Compile) = .empty;
    targets.append(b.allocator, exe) catch {
        std.debug.panic("Error: Ran out of memory while appending to targets array list\n", .{});
    };

    const targets_slice = targets.toOwnedSlice(b.allocator) catch {
        std.debug.panic("Error: Ran out of memory converting targets array list into an owned slice\n", .{});
    };
    _ = zcc.createStep(b, "cdb", targets_slice);

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
