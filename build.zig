// Copyright © 2020-2021 Sören Tempel
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const Target = std.Target;
const Zig = std.zig;
const FileSource = std.build.FileSource;
const Builder = std.build.Builder;
const FeatureSet = std.Target.Cpu.Feature.Set;

pub fn build(b: *Builder) void {
    var fe310_cpu_feat = FeatureSet.empty;
    const m: std.Target.riscv.Feature = .m;
    const a: std.Target.riscv.Feature = .a;
    const c: std.Target.riscv.Feature = .c;
    fe310_cpu_feat.addFeature(@enumToInt(a));
    fe310_cpu_feat.addFeature(@enumToInt(m));
    fe310_cpu_feat.addFeature(@enumToInt(c));

    const target = Zig.CrossTarget{
        .cpu_arch = Target.Cpu.Arch.riscv32,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_features_sub = std.Target.riscv.cpu.baseline_rv32.features,
        .cpu_features_add = fe310_cpu_feat,
    };

    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("main", "src/init.zig");
    exe.setLinkerScriptPath(FileSource{ .path = "fe310_g000.ld" });
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.addCSourceFile("src/start.S", &[_][]const u8{});
    exe.addCSourceFile("src/irq.S", &[_][]const u8{});
    exe.addCSourceFile("src/clock.c", &[_][]const u8{});

    exe.addPackage(std.build.Pkg{
        .name = "zoap",
        .path = FileSource{ .path = "./zoap/src/zoap.zig" },
    });

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
