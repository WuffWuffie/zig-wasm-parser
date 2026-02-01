const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .cpu_model = .{
            .explicit = &std.Target.wasm.cpu.generic,
        },
    } });
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.rdynamic = true;
    exe.entry = .disabled;
    exe.import_symbols = true;
    exe.stack_size = 65536;

    b.installArtifact(exe);
}
