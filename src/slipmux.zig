const zoap = @import("zoap");
const crc = @import("crc.zig");
const std = @import("std");
const console = @import("console.zig");

const Plic = @import("plic.zig").Plic;
const Uart = @import("uart.zig").Uart;

const FrameHandler = fn (buf: []const u8) void;

// SLIP (as defined in RFC 1055) doesn't specify an MTU.
const SLIP_MTU: u32 = 1500;

const Slip = struct {
    uart: Uart,
    handler: FrameHandler,
    rcvbuf: [SLIP_MTU]u8 = undefined,
    rcvpos: usize = 0,
    prev_esc: bool = false,

    const SLIP_END: u8 = 0o300;
    const SLIP_ESC: u8 = 0o333;
    const SLIP_ESC_END: u8 = 0o334;
    const SLIP_ESC_ESC: u8 = 0o335;

    fn writeByte(self: *Slip, byte: u8) void {
        self.rcvbuf[self.rcvpos] = byte;
        self.rcvpos += 1;

        self.prev_esc = false;
    }

    fn handleByte(self: *Slip, byte: u8) !void {
        if (self.rcvpos >= self.rcvbuf.len)
            return error.FrameTooLarge;

        switch (byte) {
            SLIP_ESC => {
                self.prev_esc = true;
            },
            SLIP_END => {
                self.handler(self.rcvbuf[0..self.rcvpos]);
                self.rcvpos = 0;
            },
            SLIP_ESC_END, SLIP_ESC_ESC => {
                var c: u8 = undefined;
                if (self.prev_esc) {
                    c = switch (byte) {
                        SLIP_ESC_END => SLIP_END,
                        SLIP_ESC_ESC => SLIP_ESC,
                        else => unreachable,
                    };
                } else {
                    c = byte;
                }

                self.writeByte(c);
            },
            else => {
                self.writeByte(byte);
            },
        }
    }

    fn rxIrqHandler(self: *Slip) !void {
        var n: usize = 0;
        while (true) {
            const byte = self.uart.readByte() catch |err| {
                if (err == error.EndOfStream)
                    break;
                unreachable;
            };

            try self.handleByte(byte);
        }
    }

    fn irqHandler(ctx: ?*c_void) void {
        var self: *Slip = @ptrCast(*Slip, @alignCast(@alignOf(Slip), ctx));

        const ip = self.uart.readIp();
        if (ip.rxwm) {
            rxIrqHandler(self) catch {
                @panic("rx handler failed");
            };
        } else if (ip.txwm) {
            @panic("unexpected pending transmit");
        }
    }

    pub fn init(uart: Uart, plic: Plic, func: FrameHandler) !Slip {
        uart.writeIe(Uart.ie{
            .txwm = false,
            .rxwm = true,
        });

        var self = Slip{
            .uart = uart,
            .handler = func,
        };
        try plic.registerHandler(uart.irq, irqHandler, &self);
        return self;
    }
};

pub const SlipMux = struct {
    slip: Slip,

    const FRAME_IP4 = .{ @as(u8, 0x45), @as(u8, 0x4f) };
    const FRAME_IP6 = .{ @as(u8, 0x60), @as(u8, 0x6f) };
    const FRAME_DBG: u8 = 0x0a;
    const FRAME_COAP: u8 = 0xA9;

    fn handleCoAP(buf: []const u8) !void {
        if (buf.len <= 3)
            return error.CoAPFrameTooShort;
        if (!crc.validCsum(buf))
            return error.InvalidChecksum;

        // Strip frame identifier and 16-bit CRC FCS.
        const msgBuf = buf[1..(buf.len - @sizeOf(u16))];

        var par = try zoap.Parser.init(msgBuf);
        const uri = try par.find_option(zoap.options.URIPath);

        if (par.header.code.equal(zoap.codes.PUT)) {
            if (std.mem.eql(u8, uri.value, "panic")) {
                @panic("User requested a panic!");
            }
        }
    }

    fn dispatchFrame(buf: []const u8) !void {
        switch (buf[0]) {
            FRAME_IP4[0]...FRAME_IP4[1] => {
                return error.NoIPv4Support;
            },
            FRAME_IP6[0]...FRAME_IP6[1] => {
                return error.NoIPv6Support;
            },
            FRAME_DBG => {
                return error.NoDiagnosticSupport;
            },
            FRAME_COAP => {
                try handleCoAP(buf);
            },
            else => {
                return error.UnknownFrame;
            },
        }
    }

    fn handleFrame(buf: []const u8) void {
        if (buf.len == 0)
            return;

        dispatchFrame(buf) catch |err| {
            console.print("handleFrame failed: {}\n", .{@errorName(err)});
        };
    }

    pub fn init(uart: Uart, plic: Plic) !SlipMux {
        var slip = try Slip.init(uart, plic, handleFrame);
        return SlipMux{
            .slip = slip,
        };
    }
};
