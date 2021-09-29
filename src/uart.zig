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

// Offsets for memory mapped UART control registers.
const UART_REG_TXFIFO: usize = 0x00;
const UART_REG_RXFIFO: usize = 0x04;
const UART_REG_TXCTRL: usize = 0x08;
const UART_REG_RXCTRL: usize = 0x0c;
const UART_REG_IE: usize = 0x10;
const UART_REG_IP: usize = 0x14;
const UART_REG_DIV: usize = 0x18;

const UART_TX_WATERMARK: u3 = 1;
const UART_RX_WATERMARK: u3 = 1;

// TODO: Extract this value using the PRCI.
const CLK_FREQ = 16 * 1000 * 1000; // 16 MHZ

pub const Uart = struct {
    base_addr: usize,
    rx_pin: gpio.Pin,
    tx_pin: gpio.Pin,
    irq: plic.Irq,

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

    fn writeWord(self: Uart, offset: usize, value: u32) void {
        const ptr = @intToPtr(*volatile u32, self.base_addr + offset);
        ptr.* = value;
    }

    fn readWord(self: Uart, offset: usize) u32 {
        const ptr = @intToPtr(*u32, self.base_addr + offset);
        return ptr.*;
    }

    pub fn writeTxctrl(self: Uart, ctrl: txctrl) void {
        var serialized = @bitCast(u32, ctrl);
        self.writeWord(UART_REG_TXCTRL, serialized);
    }

    pub fn writeRxctrl(self: Uart, ctrl: rxctrl) void {
        var serialized = @bitCast(u32, ctrl);
        self.writeWord(UART_REG_RXCTRL, serialized);
    }

    pub fn readIp(self: Uart) ie {
        const ip = self.readWord(UART_REG_IP);
        return @bitCast(ie, ip);
    }

    pub fn writeIe(self: Uart, val: ie) void {
        var serialized = @bitCast(u32, val);
        self.writeWord(UART_REG_IE, serialized);
    }

    pub fn writeByte(self: Uart, value: u8) void {
        self.writeWord(UART_REG_TXFIFO, value);
    }

    // TODO: Use optional instead of error
    pub fn readByte(self: Uart) !u8 {
        // TODO: use a packed struct for the rxdata register, with
        // Zig 0.6 doing so unfourtunatly triggers a compiler bug.
        const rxdata = self.readWord(UART_REG_RXFIFO);

        if ((rxdata & (1 << 31)) != 0)
            return error.EndOfStream;
        return @truncate(u8, rxdata);
    }

    pub fn isTxFull(self: Uart) bool {
        // TODO: use a packed struct for the txdata register, with
        // Zig 0.6 doing so unfourtunatly triggers a compiler bug.
        const txdata = self.readWord(UART_REG_TXFIFO);
        return (txdata & (1 << 31)) != 0;
    }

    pub fn init(self: Uart, ugpio: gpio.Gpio, baud: u32) void {
        // Enable the UART at the given baud rate
        self.writeWord(UART_REG_DIV, CLK_FREQ / baud);

        // Enable transmission
        self.writeTxctrl(txctrl{
            .txen = true,
            .nstop = 0,
            .txcnt = 1,
        });

        ugpio.setIOFCtrl(self.tx_pin, 0);
    }
};
