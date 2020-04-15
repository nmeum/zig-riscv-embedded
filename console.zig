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

// This file provides a high-level wrapper around the FU310 UART, the
// implementation is currently not interrupt-driven. A separate
// implementation (implementing the same interface?) should be added
// which *is* interrupt-driven. Alternatively, the functionality could
// be optionally added to the existing implementation.
//
// Additionally, implementing an OutStream and InStream should be
// considered, see the following resources for more information:
//
//  * https://ziglang.org/documentation/master/std/#std;io.OutStream
//  * https://ziglang.org/documentation/master/std/#std;io.InStream
//  * https://github.com/im-tomu/fomu-workshop/blob/master/riscv-zig-blink/src/fomu.zig

const Uart = @import("uart.zig").Uart;

pub const Console = struct {
    uart: Uart,

    // This implementation blocks (busy waits) if the FIFO is currently
    // full, could be preferable to perform a short-write instead in
    // this case.
    //
    // XXX:: std.io.Outstream distincts write and writeAll for this purpose.
    pub fn write(self: Console, data: []const u8) void {
        for (data) |c| {
            // If FIFO is full busy wait until it isn't.
            while (self.uart.isTxFull()) {} // XXX: use WFI?

            self.uart.writeByte(c);
        }
    }
};
