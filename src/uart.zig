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

const gpio = @import("gpio.zig");
const plic = @import("plic.zig");

// TODO: Extract this value using the PRCI.
const CLK_FREQ = 16 * 1000 * 1000; // 16 MHZ

pub const ConfFlags = struct {
    tx: bool,
    rx: bool,
    cnt: u3 = 1,
};

pub const Uart = struct {
    base_addr: usize,
    rx_pin: gpio.Pin,
    tx_pin: gpio.Pin,
    irq: plic.Irq,

    const Reg = enum(usize) {
        TXFIFO = 0x00,
        RXFIFO = 0x04,
        TXCTRL = 0x08,
        RXCTRL = 0x0c,
        IE = 0x10,
        IP = 0x14,
        DIV = 0x18,
    };

    pub const FIFO_DEPTH: usize = 8;

    pub const txctrl = packed struct {
        txen: bool,
        nstop: u1,
        _: u14 = undefined, // reserved
        txcnt: u3,
        __: u13 = undefined, // reserved
    };

    pub const rxctrl = packed struct {
        rxen: bool,
        _: u15 = undefined, // reserved
        rxcnt: u3,
        __: u13 = undefined, // reserved
    };

    pub const ie = packed struct {
        txwm: bool,
        rxwm: bool,
        _: u30 = undefined, // reserved
    };

    fn writeWord(self: Uart, reg: Reg, value: u32) void {
        const ptr = @intToPtr(*volatile u32, self.base_addr + @enumToInt(reg));
        ptr.* = value;
    }

    fn readWord(self: Uart, reg: Reg) u32 {
        const ptr = @intToPtr(*u32, self.base_addr + @enumToInt(reg));
        return ptr.*;
    }

    pub fn writeTxctrl(self: Uart, ctrl: txctrl) void {
        var serialized = @bitCast(u32, ctrl);
        self.writeWord(Reg.TXCTRL, serialized);
    }

    pub fn writeRxctrl(self: Uart, ctrl: rxctrl) void {
        var serialized = @bitCast(u32, ctrl);
        self.writeWord(Reg.RXCTRL, serialized);
    }

    pub fn readIp(self: Uart) ie {
        const ip = self.readWord(Reg.IP);
        return @bitCast(ie, ip);
    }

    pub fn writeIe(self: Uart, val: ie) void {
        var serialized = @bitCast(u32, val);
        self.writeWord(Reg.IE, serialized);
    }

    pub fn writeByte(self: Uart, value: u8) void {
        self.writeWord(Reg.TXFIFO, value);
    }

    // TODO: Use optional instead of error
    pub fn readByte(self: Uart) !u8 {
        // TODO: use a packed struct for the rxdata register, with
        // Zig 0.6 doing so unfourtunatly triggers a compiler bug.
        const rxdata = self.readWord(Reg.RXFIFO);

        if ((rxdata & (1 << 31)) != 0)
            return error.EndOfStream;
        return @truncate(u8, rxdata);
    }

    pub fn isTxFull(self: Uart) bool {
        // TODO: use a packed struct for the txdata register, with
        // Zig 0.6 doing so unfourtunatly triggers a compiler bug.
        const txdata = self.readWord(Reg.TXFIFO);
        return (txdata & (1 << 31)) != 0;
    }

    pub fn init(self: Uart, ugpio: gpio.Gpio, baud: u32, mode: ConfFlags) void {
        // Enable the UART at the given baud rate
        self.writeWord(Reg.DIV, CLK_FREQ / baud);

        self.writeTxctrl(txctrl{
            .txen = mode.tx,
            .nstop = 0,
            .txcnt = mode.cnt,
        });

        self.writeRxctrl(rxctrl{
            .rxen = mode.rx,
            .rxcnt = mode.cnt,
        });

        if (mode.tx)
            ugpio.setIOFCtrl(self.tx_pin, 0);
        if (mode.rx)
            ugpio.setIOFCtrl(self.rx_pin, 0);
    }
};
