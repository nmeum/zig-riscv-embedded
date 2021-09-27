const zoap = @import("zoap");

const Plic = @import("plic.zig").Plic;
const Irq = @import("plic.zig").Irq;
const Uart = @import("uart.zig").Uart;

// SLIP (as defined in RFC 1055) doesn't specify an MTU.
const SLIP_MTU: u32 = 1500;

const SLIP_END: u8 = 0o300;
const SLIP_ESC: u8 = 0o333;
const SLIP_ESC_END: u8 = 0o334;
const SLIP_ESC_ESC: u8 = 0o335;

const SLIPMUX_IP4 = .{ @as(u8, 0x45), @as(u8, 0x4f) };
const SLIPMUX_IP6 = .{ @as(u8, 0x60), @as(u8, 0x6f) };
const SLIPMUX_DBG: u8 = 0x0a;
const SLIPMUX_COAP: u8 = 0xA9;

const FrameHandler = fn (args: []const u8) void;

const Slip = struct {
    uart: Uart,
    handler: FrameHandler,
    rcvbuf: [SLIP_MTU]u8 = undefined,
    rcvpos: usize = 0,
    prev_esc: bool = false,

    fn write_byte(self: *Slip, byte: u8) void {
        self.rcvbuf[self.rcvpos] = byte;
        self.rcvpos += 1;

        self.prev_esc = false;
    }

    fn handle_byte(self: *Slip, byte: u8) !void {
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

                self.write_byte(c);
            },
            else => {
                self.write_byte(byte);
            },
        }
    }

    fn rxIrqHandler(self: *Slip) !void {
        var n: usize = 0;
        while (n < Uart.FIFO_DEPTH) : (n += 1) {
            const byte = self.uart.readByte() catch |err| {
                if (err == error.EndOfStream)
                    break;
                unreachable;
            };

            try self.handle_byte(byte);
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

    pub fn init(uart: Uart, plic: Plic, irq: Irq, func: FrameHandler) !Slip {
        uart.writeTxctrl(Uart.txctrl{
            .txen = true,
            .nstop = 0,
            .txcnt = 1,
        });
        uart.writeIe(Uart.ie{
            .txwm = false,
            .rxwm = true,
        });

        var self = Slip{
            .uart = uart,
            .handler = func,
        };
        try plic.registerHandler(irq, irqHandler, &self);
        return self;
    }
};

pub const SlipMux = struct {
    slip: Slip,

    fn handle_coap(buf: []const u8) void {
        // TODO: Checksuming
        var par = zoap.Parser.init(buf) catch {
            @panic("CoAP message parsing failed");
        };
    }

    fn handle_frame(buf: []const u8) void {
        if (buf.len == 0)
            return;

        const fst = buf[0];
        if (fst >= SLIPMUX_IP4[0] and fst <= SLIPMUX_IP4[1])
            @panic("support for IPv4 not implemented");
        if (fst >= SLIPMUX_IP6[0] and fst <= SLIPMUX_IP6[1])
            @panic("support for IPv6 not implemented");
        if (fst == SLIPMUX_DBG)
            @panic("support for diagnostic messages not implemented");
        if (fst == SLIPMUX_COAP)
            handle_coap(buf);
    }

    pub fn init(uart: Uart, plic: Plic, irq: Irq) !SlipMux {
        var slip = try Slip.init(uart, plic, irq, handle_frame);
        return SlipMux{
            .slip = slip,
        };
    }
};
