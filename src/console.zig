// Copyright © 2021 Sören Tempel
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

const periph = @import("periph.zig");
const slipmux = @import("slipmux.zig");

pub fn getStdDbg() slipmux.Frame {
    const ftype = slipmux.SlipMux.FrameType.diagnostic;
    return periph.slipmux.newFrame(ftype);
}

// Write a Slipmux diagnostic message, unbuffered, to the UART.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    const stddbg = getStdDbg();
    defer stddbg.close();

    const w = stddbg.writer();
    nosuspend w.print(fmt, args) catch return;
}
