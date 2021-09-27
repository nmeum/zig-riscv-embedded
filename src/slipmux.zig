const plic = @import("plic.zig");
const uart = @import("uart.zig");

// SLIP (as defined in RFC 1055) doesn't specify an MTU.
const SLIP_MTU: u32 = 1500;

const SLIP_END: u8 = 0o300;
const SLIP_ESC: u8 = 0o333;
const SLIP_ESC_END: u8 = 0o334;
const SLIP_ESC_ESC: u8 = 0o335;

pub const FrameHandler = fn (args: []const u8) !void;

pub const Slip = struct {
    uart: uart.Uart,
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
                try self.handler(rcvbuf[0..rcvpos]);
                rcvpos = 0;
            },
            SLIP_END_ESC, SLIP_ESC_ESC => {
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
        while (n < uart.Uart.FIFO_DEPTH) : (n += 1) {
            const byte = io.uart.readByte() catch |err| {
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
            rxIrqHandler(self) catch |err| {
                @panic(err);
            };
        }
    }

    pub fn init(uart: Uart, plic: Plic, irq: plic.Irq, func: FrameHandler) Slip {
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
        try plic.registerHandler(irq, irqHandler, self);
        return self;
    }
};
