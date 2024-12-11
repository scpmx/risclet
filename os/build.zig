const std = @import("std");
const CrossTarget = @import("std").zig.CrossTarget;
const Target = @import("std").Target;
const Feature = @import("std").Target.Cpu.Feature;

pub fn build(b: *std.Build) void {
    const features = Target.riscv.Feature;
    var disabled_features = Feature.Set.empty;
    const enabled_features = Feature.Set.empty;

    // disable all CPU extensions
    disabled_features.addFeature(@intFromEnum(features.a));
    disabled_features.addFeature(@intFromEnum(features.c));
    disabled_features.addFeature(@intFromEnum(features.d));
    disabled_features.addFeature(@intFromEnum(features.e));
    disabled_features.addFeature(@intFromEnum(features.f));
    disabled_features.addFeature(@intFromEnum(features.m));

    const target = b.resolveTargetQuery(.{ // Prevent
        .cpu_arch = Target.Cpu.Arch.riscv32,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    });

    const exe = b.addExecutable(.{
        .name = "os",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const bin = b.addObjCopy(exe.getEmittedBin(), .{
        .format = .elf,
    });

    bin.step.dependOn(&exe.step);

    const copy_bin = b.addInstallBinFile(bin.getOutput(), "os.elf");
    b.default_step.dependOn(&copy_bin.step);
}
