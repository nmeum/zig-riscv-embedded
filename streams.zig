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
            self.writeByte(c);
        }

        return data.len;
    }

    pub fn init(uart: Uart) OutStream {
        return .{ .context = uart };
    }
};

const Fifo = std.fifo.LinearFifo(u8, .{ .Static = 32 });

// XXX: This is a dirty hack to work around the fact that it is not
// possible to pass any context to an IRQ handler. A global variable
// is thus used to obtain this context for now.
//
// Keep in mind that this is also used for memory allocation currently.
var irq_stream: ?BufferedOutStream = null;

pub const BufferedOutStream = struct {
    plic: Plic,
    uart: Uart,
    fifo: Fifo = Fifo.init(),

    const Error = error{OutOfMemory};
    const OutStream = io.OutStream(*Self, Error, write);

    const Self = @This();

    fn irqHandler() void {
        var stream: *BufferedOutStream = &irq_stream.?;
        const ip = stream.uart.readIp();
        if (!ip.txwm)
            return; // Not a transmit interrupt

        var count = Uart.FIFO_DEPTH;
        while (count > 0) : (count -= 1) {
            const c: u8 = stream.fifo.readItem() catch |err| {
                if (err == error.EndOfStream)
                    break;
                unreachable;
            };
            stream.uart.writeByte(c);
        }

        if (stream.fifo.readableLength() == 0) {
            stream.uart.writeIe(Uart.ie{
                .txwm = false,
                .rxwm = false,
            });
        }
    }

    fn write(self: *BufferedOutStream, data: []const u8) Error!usize {
        // XXX: Consider blocking (WFI) instead of performing short write?
        var maxlen: usize = data.len;
        if (maxlen >= self.fifo.writableLength())
            maxlen = self.fifo.writableLength();
        self.fifo.writeAssumeCapacity(data[0..maxlen]);

        self.uart.writeIe(Uart.ie{
            .txwm = true,
            .rxwm = false,
        });

        return maxlen;
    }

    pub fn init(irq: Irq, pdriver: Plic, udriver: Uart) !OutStream {
        irq_stream = BufferedOutStream{
            .plic = pdriver,
            .uart = udriver,
        };

        // Threshold is not reset to zero by default.
        pdriver.setThreshold(0);

        var ptr: *BufferedOutStream = &(irq_stream.?);
        try pdriver.registerHandler(irq, irqHandler);

        udriver.writeTxctrl(Uart.txctrl{
            .txen = true,
            .nstop = 0,
            .txcnt = 1,
        });

        return OutStream{ .context = ptr };
    }
};
