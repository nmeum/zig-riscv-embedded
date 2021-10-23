// Copyright © 2020 Sören Tempel
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the
// Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
// Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program. If not, see <http://www.gnu.org/licenses/>.

const std = @import("std");
const Target = std.Target;
const Zig = std.zig;
const Builder = std.build.Builder;
const FeatureSet = std.Target.Cpu.Feature.Set;

pub fn build(b: *Builder) void {
    // Workaround for https://github.com/ziglang/zig/issues/9760
    var sub_set = FeatureSet.empty;
    const float: std.Target.riscv.Feature = .d;
    sub_set.addFeature(@enumToInt(float));

    const target = Zig.CrossTarget{
        .cpu_arch = Target.Cpu.Arch.riscv32,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_features_sub = sub_set,
    };

    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("main", "src/init.zig");
    exe.linker_script = "fe310_g000.ld";
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.addCSourceFile("src/start.S", &[_][]const u8{});
    exe.addCSourceFile("src/irq.S", &[_][]const u8{});
    exe.addCSourceFile("src/clock.c", &[_][]const u8{});

    exe.addPackage(std.build.Pkg{
        .name = "zoap",
        .path = "./zoap/src/zoap.zig",
    });

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
