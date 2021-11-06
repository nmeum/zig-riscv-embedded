// Copyright © 2021 Sören Tempel
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
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

const gpio = @import("gpio.zig");
const plic = @import("plic.zig");
const uart = @import("uart.zig");
const smux = @import("slipmux.zig");

// Addresses of FE310 peripherals.
const UART0_CTRL_ADDR: usize = 0x10013000;
const UART1_CTRL_ADDR: usize = 0x10023000;
const PLIC_CTRL_ADDR: usize = 0x0C000000;
const GPIO_CTRL_ADDR: usize = 0x10012000;

// LEDs.
pub const led0 = gpio.pin(0, 22);
pub const led1 = gpio.pin(0, 19);
pub const led2 = gpio.pin(0, 21);

pub const gpio0 = gpio.Gpio{
    .base_addr = GPIO_CTRL_ADDR,
};
pub const plic0 = plic.Plic{
    .base_addr = PLIC_CTRL_ADDR,
};

const uart0 = uart.Uart{
    .base_addr = UART0_CTRL_ADDR,
    .rx_pin = gpio.pin(0, 16),
    .tx_pin = gpio.pin(0, 17),
    .irq = 3,
};
var slip0 = smux.Slip{
    .uart = &uart0,
    .plic = &plic0,
};
pub var slipmux = smux.SlipMux{
    .slip = &slip0,
};

pub fn init() void {
    plic0.init();
    uart0.init(gpio0, .{ .tx = true, .rx = true });

    gpio0.init(led0, gpio.Mode.OUT);
    gpio0.init(led1, gpio.Mode.OUT);
    gpio0.init(led2, gpio.Mode.OUT);

    gpio0.set(led0, 1);
    gpio0.set(led1, 1);
    gpio0.set(led2, 1);
}
