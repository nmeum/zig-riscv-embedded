// Copyright © 2020-2021 Sören Tempel
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program. If not, see <https://www.gnu.org/licenses/>.

const gpio = @import("gpio.zig");
const plic = @import("plic.zig");

// TODO: Extract this value using the PRCI.
const CLK_FREQ = 16 * 1000 * 1000; // 16 MHZ

pub const ConfFlags = struct {
    tx: bool,
    rx: bool,
    cnt: u3 = 0,
    baud: u32 = 115200,
};

fn ctrlCount(watermark: u3) u32 {
    return (@as(u32, watermark) & 0x07) << 16;
}

pub const Uart = struct {
    base_addr: usize,
    rx_pin: gpio.Pin,
    tx_pin: gpio.Pin,
    irq: plic.Irq,

    const Reg = enum(usize) {
        txfifo = 0x00,
        rxfifo = 0x04,
        txctrl = 0x08,
        rxctrl = 0x0c,
        ie = 0x10,
        ip = 0x14,
        div = 0x18,
    };

    pub const ie = struct {
        txwm: bool,
        rxwm: bool,
    };

    pub const FIFO_DEPTH: usize = 8;
    pub const TXCTRL_ENABLE: u32 = 1;
    pub const RXCTRL_ENABLE: u32 = 1;
    pub const EMPTY_MASK: u32 = 1 << 31; // for txdata/rxdata
    pub const IE_TXWM: u32 = 1 << 0;
    pub const IE_RXWM: u32 = 1 << 1;

    fn writeWord(self: Uart, reg: Reg, value: u32) void {
        const ptr = @intToPtr(*volatile u32, self.base_addr + @enumToInt(reg));
        ptr.* = value;
    }

    fn readWord(self: Uart, reg: Reg) u32 {
        const ptr = @intToPtr(*volatile u32, self.base_addr + @enumToInt(reg));
        return ptr.*;
    }

    pub fn confTx(self: Uart, watermark: u3) void {
        self.writeWord(Reg.txctrl, TXCTRL_ENABLE | ctrlCount(watermark));
    }

    pub fn confRx(self: Uart, watermark: u3) void {
        self.writeWord(Reg.rxctrl, RXCTRL_ENABLE | ctrlCount(watermark));
    }

    pub fn readIp(self: Uart) ie {
        const r = self.readWord(Reg.ip);
        return .{
            .txwm = (r & IE_TXWM) != 0,
            .rxwm = (r & IE_RXWM) != 0,
        };
    }

    pub fn writeIe(self: Uart, txwm: bool, rxwm: bool) void {
        var r: u32 = 0;
        if (txwm)
            r |= IE_TXWM;
        if (rxwm)
            r |= IE_RXWM;

        self.writeWord(Reg.ie, r);
    }

    pub fn writeByte(self: Uart, value: u8) void {
        self.writeWord(Reg.txfifo, value);
    }

    fn drainInput(self: Uart) void {
        // Read until self.readByte() returns null
        while (self.readByte()) |_| {}
    }

    pub fn readByte(self: Uart) ?u8 {
        const rxdata = self.readWord(Reg.rxfifo);
        if ((rxdata & EMPTY_MASK) != 0)
            return null;
        return @truncate(u8, rxdata);
    }

    pub fn isTxFull(self: Uart) bool {
        const txdata = self.readWord(Reg.txfifo);
        return (txdata & EMPTY_MASK) != 0;
    }

    pub fn init(self: Uart, ugpio: gpio.Gpio, conf: ConfFlags) void {
        // Enable the UART at the given baud rate
        self.writeWord(Reg.div, CLK_FREQ / conf.baud);

        if (conf.tx)
            self.confTx(conf.cnt);
        if (conf.rx)
            self.confRx(conf.cnt);

        if (conf.tx)
            ugpio.setIOFCtrl(self.tx_pin, 0);
        if (conf.rx)
            ugpio.setIOFCtrl(self.rx_pin, 0);

        if (conf.rx)
            self.drainInput();
    }
};
