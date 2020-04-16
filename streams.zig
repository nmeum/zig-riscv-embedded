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

pub const BufferedStream = struct {
    plic: Plic,
    uart: Uart,
    fifo: Fifo = Fifo.init(),

    const OutError = error{OutOfMemory};
    const OutStream = io.OutStream(*Self, OutError, write);

    const InError = error{};
    const InStream = io.InStream(*Self, InError, read);

    const Self = @This();

    fn txIrqHandler(stream: *BufferedStream) void {
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

    fn rxIrqHandler(stream: *BufferedStream) void {
        return; // TODO
    }

    fn irqHandler(ctx: ?*c_void) void {
        var stream: *BufferedStream = @ptrCast(*BufferedStream, @alignCast(@alignOf(BufferedStream), ctx));

        const ip = stream.uart.readIp();
        if (ip.txwm)
            txIrqHandler(stream);
        if (ip.rxwm)
            rxIrqHandler(stream);
    }

    fn write(self: *BufferedStream, data: []const u8) OutError!usize {
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

    fn read(self: *BufferedStream, dest: []u8) InError!usize {
        return 0;
    }

    pub fn outStream(self: *Self) OutStream {
        return .{ .context = self };
    }

    pub fn inStream(self: *Self) InStream {
        return .{ .context = self };
    }

    pub fn init(self: *Self, irq: Irq) !void {
        // Threshold is not reset to zero by default.
        self.plic.setThreshold(0);

        try self.plic.registerHandler(irq, irqHandler, self);
        self.uart.writeTxctrl(Uart.txctrl{
            .txen = true,
            .nstop = 0,
            .txcnt = 1,
        });
    }
};
