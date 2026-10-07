const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const protocol_mod = b.addModule("protocol", .{
        .root_source_file = b.path("src/protocol/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const sys_mod = b.addModule("sys", .{
        .root_source_file = b.path("src/sys/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const server_exe = b.addExecutable(.{
        .name = "redstone-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/server/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
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
                .{ .name = "protocol", .module = protocol_mod },
                .{ .name = "sys", .module = sys_mod },
            },
        }),
    });
    b.installArtifact(cli_exe);
}
