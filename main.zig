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

const UART = @import("uart.zig").UART;

// UART control base addresses.
const UART0_CTRL_ADDR: u32 = 0x10013000;
const UART1_CTRL_ADDR: u32 = 0x10023000;

// TODO
const UART0_IRQ = 3;
const UART1_IRQ = 4;

// TODO
const PLIC_CTRL_ADDR: u32 = 0x0C000000;
const PLIC_PRIO_OFF: u32 = 0x0000;
const PLIC_PENDING_OFF: u32 = 0x1000;
const PLIC_ENABLE_OFF: u32 = 0x2000;
const PLIC_CONTEXT_OFF: u32 = 0x200000;

// TODO
const MCAUSE_IRQ_MASK: u32 = 31;

// TODO
var uart1: UART = UART{
    .base_addr = UART0_CTRL_ADDR,
    .irq = UART0_IRQ,
};

export fn lvl1_handler() void {
    const mcause = asm ("csrr %[ret], mcause"
        : [ret] "=r" (-> u32)
    );

    if ((mcause >> MCAUSE_IRQ_MASK) != 1)
        return; // not an interrupt

    const claim_reg = @intToPtr(*volatile u32, PLIC_CTRL_ADDR + PLIC_CONTEXT_OFF + @sizeOf(u32));
    const irq = claim_reg.*;
    if (irq != UART0_IRQ)
        return; // not our IRQ

    uart1.write_byte('H');
    uart1.write_byte('e');
    uart1.write_byte('l');
    uart1.write_byte('l');
    uart1.write_byte('l');
    uart1.write_byte('o');
    uart1.write_byte('!');
    uart1.write_byte('\n');

    // Mark interrupt as completed
    claim_reg.* = irq;
}

export fn myinit() void {
    // Set PLIC priority for UART interrupt
    const plic_prio = @intToPtr(*volatile u32, PLIC_CTRL_ADDR +
        PLIC_PRIO_OFF + (UART0_IRQ * @sizeOf(u32)));
    plic_prio.* = 1;

    // Set PLIC threshold
    const plic_thres = @intToPtr(*volatile u32, PLIC_CTRL_ADDR + PLIC_CONTEXT_OFF);
    plic_thres.* = 0;

    // Enable interrupts for UART interrupt
    const plic_enable = @intToPtr(*volatile u32, PLIC_CTRL_ADDR + PLIC_ENABLE_OFF);
    plic_enable.* = 1 << UART0_IRQ;

    uart1.writeTxctrl(UART.txctrl{
        .txen = true,
        .nstop = 0,
        .txcnt = 1,
    });
    uart1.writeIe(UART.ie{
        .txwm = true,
        .rxwm = false,
    });

    return;
}
