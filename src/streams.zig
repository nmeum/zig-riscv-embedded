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
const io = std.io;
const math = std.math;

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
    tx_fifo: Fifo = Fifo.init(),
    rx_fifo: Fifo = Fifo.init(),

    const OutError = error{OutOfMemory};
    const OutStream = io.OutStream(*Self, OutError, write);

    const InError = error{};
    const InStream = io.InStream(*Self, InError, read);

    const Self = @This();

    fn txIrqHandler(stream: *BufferedStream) void {
        var count = Uart.FIFO_DEPTH;
        while (count > 0) : (count -= 1) {
            const c = stream.tx_fifo.readItem();
            if (c == null) {
                break;
            }
            stream.uart.writeByte(c.?);
        }

        if (stream.tx_fifo.readableLength() == 0) {
            stream.uart.writeIe(Uart.ie{
                .txwm = false,
                .rxwm = true,
            });
        }
    }

    fn rxIrqHandler(stream: *BufferedStream) void {
        var buf: [Uart.FIFO_DEPTH]u8 = undefined;

        var n: usize = 0;
        while (n < buf.len) : (n += 1) {
            buf[n] = stream.uart.readByte() catch |err| {
                if (err == error.EndOfStream)
                    break;
                unreachable;
            };
        }

        if (stream.rx_fifo.writableLength() < n)
            stream.rx_fifo.discard(n);

        stream.rx_fifo.writeAssumeCapacity(buf[0..n]);
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
        var maxlen: usize = math.min(data.len, self.tx_fifo.writableLength());
        self.tx_fifo.writeAssumeCapacity(data[0..maxlen]);

        self.uart.writeIe(Uart.ie{
            .txwm = true,
            .rxwm = true,
        });

        return maxlen;
    }

    fn read(self: *BufferedStream, dest: []u8) InError!usize {
        while (self.rx_fifo.readableLength() == 0)
            asm volatile ("WFI");

        return self.rx_fifo.read(dest);
    }

    pub fn outStream(self: *Self) OutStream {
        return .{ .context = self };
    }

    pub fn inStream(self: *Self) InStream {
        return .{ .context = self };
    }

    pub fn init(self: *Self, irq: Irq) !void {
        try self.plic.registerHandler(irq, irqHandler, self);
        self.uart.writeTxctrl(Uart.txctrl{
            .txen = true,
            .nstop = 0,
            .txcnt = 1,
        });

        self.uart.writeIe(Uart.ie{
            .txwm = false,
            .rxwm = true,
        });
    }
};
