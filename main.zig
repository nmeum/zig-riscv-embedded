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
const Console = @import("console.zig").Console;
const StackTrace = @import("std").builtin.StackTrace;

// Addresses of FE310 peripherals.
const UART0_CTRL_ADDR: usize = 0x10013000;
const UART1_CTRL_ADDR: usize = 0x10023000;
const PLIC_CTRL_ADDR: usize = 0x0C000000;

// IRQ lines used by FE310 peripherals.
const UART0_IRQ = 3;
const UART1_IRQ = 4;

var plic1: Plic = Plic{
    .base_addr = PLIC_CTRL_ADDR,
};
const uart1: Uart = Uart{
    .base_addr = UART0_CTRL_ADDR,
};
const console: Console = Console{
    .uart = uart1,
};

pub fn panic(msg: []const u8, error_return_trace: ?*StackTrace) noreturn {
    @setCold(true); // copied from the default_panic implementation

    // TODO: emit some kind of error message

    asm volatile ("EBREAK");
    while (true) {}
}

pub fn uart_irq() void {
    const ip = uart1.readIp();
    if (!ip.txwm)
        return; // Not a transmit interrupt

    console.write("Hello!\n");
}

export fn level1IRQHandler() void {
    plic1.invoke_handler();
}

export fn myinit() void {
    plic1.setThreshold(0);
    plic1.register_handler(UART0_IRQ, uart_irq) catch |err| {
        // TODO: emit error message
        @panic("error encountered");
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
