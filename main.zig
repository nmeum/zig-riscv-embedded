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

// UART control base addresses.
const UART0_CTRL_ADDR: u32 = 0x10013000;
const UART1_CTRL_ADDR: u32 = 0x10023000;

// TODO
const UART0_IRQ = 3;
const UART1_IRQ = 4;

// Offsets for memory mapped UART control registers.
const UART_REG_TXFIFO : u32 = 0x00;
const UART_REG_RXFIFO : u32 = 0x04;
const UART_REG_TXCTRL : u32 = 0x08;
const UART_REG_RXCTRL : u32 = 0x0c;
const UART_REG_IE     : u32 = 0x10;
const UART_REG_IP     : u32 = 0x14;
const UART_REG_DIV    : u32 = 0x18;

// TODO
const PLIC_CTRL_ADDR:   u32 = 0x0C000000;
const PLIC_PRIO_OFF:    u32 = 0x0000;
const PLIC_PENDING_OFF: u32 = 0x1000;
const PLIC_ENABLE_OFF:  u32 = 0x2000;
const PLIC_CONTEXT_OFF: u32 = 0x200000;

// TODO
const MCAUSE_IRQ_MASK: u32 = 31;

export fn lvl1_handler() void {
    const mcause =asm ("csrr %[ret], mcause"
        : [ret] "=r" (-> u32));

    if ((mcause >> MCAUSE_IRQ_MASK) != 1)
        return; // not an interrupt

    const claim_reg = @intToPtr(*volatile u32, PLIC_CTRL_ADDR + PLIC_CONTEXT_OFF + @sizeOf(u32));
    const irq = claim_reg.*;
    if (irq != UART0_IRQ)
        return; // not our IRQ

    const uart0tx = @intToPtr(*volatile u32, UART0_CTRL_ADDR + UART_REG_TXFIFO);
    uart0tx.* = 'H';
    uart0tx.* = 'e';
    uart0tx.* = 'l';
    uart0tx.* = 'l';
    uart0tx.* = 'o';
    uart0tx.* = '!';
    uart0tx.* = '\n';

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

    // Set UART watermark
    const uart_txctrl = @intToPtr(*volatile u32, UART0_CTRL_ADDR + UART_REG_TXCTRL);
    uart_txctrl.* = (1 << 16);

    // Enable UART TX interrupt
    const uart_ie = @intToPtr(*volatile u32, UART0_CTRL_ADDR + UART_REG_IE);
    uart_ie.* = (1 << 0);

    return;
}
