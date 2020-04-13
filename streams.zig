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

const Uart = @import("uart.zig").Uart;
const io = @import("std").io;

pub const UnbufferedOutStream = struct {
    const Error = error{};
    const OutStream = io.OutStream(Uart, Error, write);

    fn write(self: Uart, data: []const u8) Error!usize {
        for (data) |c, i| {
            if (self.isTxFull())
                return i;
            self.write_byte(c);
        }

        return data.len;
    }

    pub fn init(uart: Uart) OutStream {
        return .{ .context = uart };
    }
};

// TODO: Add a buffered (interrupt-driven) variant
