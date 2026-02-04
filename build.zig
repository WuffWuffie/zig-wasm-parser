const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("wasm", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const dumper = b.addExecutable(.{
        .name = "dumper",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/dumper.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "wasm", .module = mod },
            },
        }),
    });

    b.installArtifact(dumper);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(dumper);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Generates instruction definitions, formatting and parsing code.
    const codegen = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/codegen.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "wasm", .module = mod },
            },
        }),
    });

    const codegen_step = b.step("codegen", "Generate instructions");
    const codegen_cmd = b.addRunArtifact(codegen);
    codegen_step.dependOn(&codegen_cmd.step);
}
