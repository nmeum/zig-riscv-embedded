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

const plic = @import("plic.zig");
const std = @import("std");
const io = @import("std").io;

const Irq = plic.Irq;
const Plic = plic.Plic;
const Uart = @import("uart.zig").Uart;

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

const Fifo = std.fifo.LinearFifo(u8, .{ .Static = 100 });

// XXX: This is a dirty hack to work around the fact that it is not
// possible to pass any context to an IRQ handler. A global variable
// is thus used to obtain this context for now.
var irq_stream: ?*BufferedOutStream = null;

pub const BufferedOutStream = struct {
    plic: Plic,
    uart: Uart,
    fifo: Fifo,

    const Error = error{OutOfMemory};
    const OutStream = io.OutStream(*Self, Error, write);

    const Self = @This();

    fn irqHandler() void {
        const stream = irq_stream orelse @panic("missing stream");

        var count = Uart.FIFO_DEPTH;
        while (count > 0) : (count -= 1) {
            const c: u8 = stream.fifo.readItem() catch |err| {
                if (err == error.EndOfStream)
                    return;
                @panic("unexpected error in irqHandler");
            };
            stream.uart.write_byte(c);
        }
    }

    fn write(self: *BufferedOutStream, data: []const u8) Error!usize {
        try self.fifo.write(data);
        return data.len;
    }

    pub fn init(irq: Irq, pdriver: Plic, udriver: Uart) !OutStream {
        var stream = BufferedOutStream{
            .plic = pdriver,
            .uart = udriver,
            .fifo = Fifo.init(),
        };

        const ptr = &stream;
        try pdriver.registerHandler(irq, irqHandler);

        irq_stream = &stream;
        return OutStream{ .context = ptr };
    }
};
