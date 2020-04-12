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

const Plic = @import("plic.zig").Plic;
const Uart = @import("uart.zig").Uart;

// UART control base addresses.
const UART0_CTRL_ADDR: usize = 0x10013000;
const UART1_CTRL_ADDR: usize = 0x10023000;

// TODO
const UART0_IRQ = 3;
const UART1_IRQ = 4;

// TODO
const PLIC_CTRL_ADDR: usize = 0x0C000000;

// TODO
var plic1: Plic = Plic{
    .base_addr = PLIC_CTRL_ADDR,
};

// TODO
var uart1: Uart = Uart{
    .base_addr = UART0_CTRL_ADDR,
};

pub fn abort(err: anyerror) noreturn {
    // TODO: emit some kind of error message
    asm volatile ("EBREAK");
    while (true) {}
}

pub fn uart_irq() void {
    const ip = uart1.readIp();
    if (!ip.txwm)
        return; // Not a transmit interrupt

    uart1.write_byte('H');
    uart1.write_byte('e');
    uart1.write_byte('l');
    uart1.write_byte('l');
    uart1.write_byte('l');
    uart1.write_byte('o');
    uart1.write_byte('!');
    uart1.write_byte('\n');
}

export fn level1IRQHandler() void {
    plic1.invoke_handler();
}

export fn myinit() void {
    plic1.setThreshold(0);
    plic1.register_handler(UART0_IRQ, uart_irq) catch |err| {
        abort(err);
    };

    uart1.writeTxctrl(Uart.txctrl{
        .txen = true,
        .nstop = 0,
        .txcnt = 1,
    });
    uart1.writeIe(Uart.ie{
        .txwm = true,
        .rxwm = false,
    });

    return;
}
