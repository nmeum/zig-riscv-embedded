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

// Offsets for memory mapped UART control registers.
const UART_REG_TXFIFO : u32 = 0x00;
const UART_REG_RXFIFO : u32 = 0x04;
const UART_REG_TXCTRL : u32 = 0x08;
const UART_REG_RXCTRL : u32 = 0x0c;
const UART_REG_IE     : u32 = 0x10;
const UART_REG_IP     : u32 = 0x14;
const UART_REG_DIV    : u32 = 0x18;

export fn lvl1_handler() void {
    // TODO
}

export fn myinit() void {
    const uart0tx = @intToPtr(*volatile u32, UART0_CTRL_ADDR + UART_REG_TXFIFO);
    uart0tx.* = 'H';
    uart0tx.* = 'e';
    uart0tx.* = 'l';
    uart0tx.* = 'l';
    uart0tx.* = 'o';
    uart0tx.* = '!';
    uart0tx.* = '\n';
}
