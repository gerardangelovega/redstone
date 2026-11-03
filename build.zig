const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const assert_mod = b.addModule("assert", .{
        .root_source_file = b.path("src/assert.zig"),
        .target = target,
        .optimize = optimize,
    });

    const protocol_mod = b.addModule("protocol", .{
        .root_source_file = b.path("src/protocol/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "assert", .module = assert_mod },
        },
    });

    const sys_mod = b.addModule("sys", .{
        .root_source_file = b.path("src/sys/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "assert", .module = assert_mod },
        },
    });

    const server_exe = b.addExecutable(.{
        .name = "redstone-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/server/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "assert", .module = assert_mod },
                .{ .name = "protocol", .module = protocol_mod },
                .{ .name = "sys", .module = sys_mod },
            },
        }),
    });
    b.installArtifact(server_exe);

    const cli_exe = b.addExecutable(.{
        .name = "redstone-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cli/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "assert", .module = assert_mod },
                .{ .name = "protocol", .module = protocol_mod },
                .{ .name = "sys", .module = sys_mod },
            },
        }),
    });
    b.installArtifact(cli_exe);

    const test_file = b.option([]const u8, "test-file", "Run only the tests in this file");

    const test_file_step = b.step("test-file", "Run tests from one file (-Dtest-file=path)");
    if (test_file) |path| {
        const file_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(path),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "assert", .module = assert_mod },
                    .{ .name = "protocol", .module = protocol_mod },
                    .{ .name = "sys", .module = sys_mod },
                },
            }),
            .filters = &.{},
        });
        var run_file_tests = b.addRunArtifact(file_tests);
        run_file_tests.has_side_effects = true;
        test_file_step.dependOn(&run_file_tests.step);
    } else {
        test_file_step.dependOn(&b.addFail("pass -Dtest-file=<path>").step);
    }
}
