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

const zoap = @import("zoap");
const crc = @import("crc.zig");
const std = @import("std");
const console = @import("console.zig");

const Plic = @import("plic.zig").Plic;
const Uart = @import("uart.zig").Uart;

const FrameHandler = fn (ctx: ?*c_void, buf: []const u8) void;
const CoapHandler = fn (req: *zoap.pkt.Request) void;

pub const Slip = struct {
    uart: Uart,
    plic: Plic,
    handler: ?FrameHandler = null,
    context: ?*c_void = null,
    rcvbuf: [MTU]u8 = undefined,
    rcvpos: usize = 0,
    prev_esc: bool = false,

    // SLIP control bytes from RFC 1055.
    const END: u8 = 0o300;
    const ESC: u8 = 0o333;
    const ESC_END: u8 = 0o334;
    const ESC_ESC: u8 = 0o335;

    // SLIP (as defined in RFC 1055) doesn't specify an MTU.
    const MTU: u32 = 1500;

    fn writeByte(self: *Slip, byte: u8) void {
        self.rcvbuf[self.rcvpos] = byte;
        self.rcvpos += 1;
    }

    fn handleByte(self: *Slip, byte: u8) !void {
        if (self.rcvpos >= self.rcvbuf.len) {
            self.prev_esc = false;
            return error.FrameTooLarge;
        }

        switch (byte) {
            ESC => {
                self.prev_esc = true;
                return;
            },
            END => {
                if (self.handler != null)
                    self.handler.?(self.context, self.rcvbuf[0..self.rcvpos]);
                self.rcvpos = 0;
            },
            ESC_END, ESC_ESC => {
                var c: u8 = undefined;
                if (self.prev_esc) {
                    switch (byte) {
                        ESC_END => c = END,
                        ESC_ESC => c = ESC,
                        else => return error.UnknownEscapeSequence,
                    }
                } else {
                    c = byte;
                }

                self.writeByte(c);
            },
            else => {
                self.writeByte(byte);
            },
        }

        self.prev_esc = false;
    }

    fn rxIrqHandler(self: *Slip) !void {
        var n: usize = 0;
        while (true) {
            if (self.uart.readByte()) |byte| {
                try self.handleByte(byte);
            } else {
                break;
            }
        }
    }

    fn irqHandler(ctx: ?*c_void) void {
        var self: *Slip = @ptrCast(*Slip, @alignCast(@alignOf(Slip), ctx));

        const ip = self.uart.readIp();
        if (ip.rxwm) {
            rxIrqHandler(self) catch {
                @panic("rx handler failed");
            };
        }
    }

    pub fn registerHandler(self: *Slip, func: FrameHandler, ctx: ?*c_void) !void {
        self.uart.writeIe(Uart.ie{
            .txwm = false,
            .rxwm = true,
        });

        self.handler = func;
        self.context = ctx;

        try self.plic.registerHandler(self.uart.irq, irqHandler, self);
    }
};

pub const Frame = struct {
    slip: Slip,

    const WriteError = error{};
    const FrameWriter = std.io.Writer(Frame, WriteError, write);

    fn pushByte(self: Frame, byte: u8) void {
        const uart = self.slip.uart;

        // Busy wait for TX fifo to empty.
        while (uart.isTxFull()) {}
        uart.writeByte(byte);
    }

    fn write(self: Frame, data: []const u8) WriteError!usize {
        for (data) |c, _| {
            switch (c) {
                Slip.END => {
                    self.pushByte(Slip.ESC);
                    self.pushByte(Slip.ESC_END);
                },
                Slip.ESC => {
                    self.pushByte(Slip.ESC);
                    self.pushByte(Slip.ESC_ESC);
                },
                else => {
                    self.pushByte(c);
                },
            }
        }

        return data.len;
    }

    pub fn close(self: Frame) void {
        self.pushByte(Slip.END);
    }

    pub fn writer(self: Frame) FrameWriter {
        return .{ .context = self };
    }
};

pub const SlipMux = struct {
    slip: Slip,
    handler: ?CoapHandler = null,

    pub const FrameType = enum(u8) {
        diagnostic = 0x0a,
        coap = 0xa9,
    };

    fn handleCoAP(self: *SlipMux, buf: []const u8) !void {
        // 1 byte (frame type) + 4 byte (coap message) + 2 byte CRC
        if (buf.len <= 7)
            return error.CoAPFrameTooShort;
        if (!crc.validCsum(buf))
            return error.InvalidChecksum;

        // Strip frame identifier and 16-bit CRC FCS.
        const msgBuf = buf[1..(buf.len - @sizeOf(u16))];

        var pkt = try zoap.pkt.Request.init(msgBuf);
        self.handler.?(&pkt);
    }

    fn dispatchFrame(self: *SlipMux, buf: []const u8) !void {
        switch (buf[0]) {
            @enumToInt(FrameType.diagnostic) => {
                return error.NoDiagnosticSupport;
            },
            @enumToInt(FrameType.coap) => {
                try self.handleCoAP(buf);
            },
            else => {
                return error.UnsupportedFrameType;
            },
        }
    }

    fn handleFrame(ctx: ?*c_void, buf: []const u8) void {
        var self: *SlipMux = @ptrCast(*SlipMux, @alignCast(@alignOf(SlipMux), ctx.?));
        if (buf.len == 0)
            return;

        self.dispatchFrame(buf) catch |err| {
            console.print("handleFrame failed: {}\n", .{@errorName(err)});
        };
    }

    pub fn newFrame(self: *SlipMux, ftype: FrameType) Frame {
        const frame = Frame{ .slip = self.slip };
        frame.pushByte(@enumToInt(ftype));
        return frame;
    }

    pub fn registerHandler(self: *SlipMux, handler: CoapHandler) !void {
        self.handler = handler;
        try self.slip.registerHandler(handleFrame, self);
    }
};
