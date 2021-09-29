// Copyright © 2021 Sören Tempel
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
const uart = @import("uart.zig");

// Baud rate for UART0 and UART1.
const BAUD_RATE = 115200;

// Addresses of FE310 peripherals.
const UART0_CTRL_ADDR: usize = 0x10013000;
const UART1_CTRL_ADDR: usize = 0x10023000;
const PLIC_CTRL_ADDR: usize = 0x0C000000;
const GPIO_CTRL_ADDR: usize = 0x10012000;

pub const gpio0 = gpio.Gpio{
    .base_addr = GPIO_CTRL_ADDR,
};
pub const plic0 = plic.Plic{
    .base_addr = PLIC_CTRL_ADDR,
};
pub const uart0 = uart.Uart{
    .base_addr = UART0_CTRL_ADDR,
    .rx_pin = gpio.pin(0, 16),
    .tx_pin = gpio.pin(0, 17),
    .irq = 3,
};
pub const uart1 = uart.Uart{
    .base_addr = UART1_CTRL_ADDR,
    .rx_pin = gpio.pin(0, 18),
    .tx_pin = gpio.pin(0, 23),
    .irq = 4,
};

pub fn init() void {
    plic0.init();

    // Initialize both uarts.
    uart0.init(gpio0, BAUD_RATE, .{ .tx = true, .rx = false });
    uart1.init(gpio0, BAUD_RATE, .{ .tx = true, .rx = true });
}
