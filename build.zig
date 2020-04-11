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

pub fn build(b: *Builder) void {
    const target = Zig.CrossTarget{
        .cpu_arch = Target.Cpu.Arch.riscv32,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
    };

    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("main", "main.zig");
    exe.linker_script = "fe310_g000.ld";
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.addCSourceFile("start.S", &[_][]const u8{});
    exe.addCSourceFile("irq.S", &[_][]const u8{});

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
