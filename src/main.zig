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

const io = @import("io.zig");
const slipmux = @import("slipmux.zig");
const Plic = @import("plic.zig").Plic;
const Uart = @import("uart.zig").Uart;
const StackTrace = @import("std").builtin.StackTrace;

// Addresses of FE310 peripherals.
const UART0_CTRL_ADDR: usize = 0x10013000;
const UART1_CTRL_ADDR: usize = 0x10023000;
const PLIC_CTRL_ADDR: usize = 0x0C000000;

// IRQ lines used by FE310 peripherals.
const UART0_IRQ = 3;
const UART1_IRQ = 4;

const MCAUSE_IRQ_MASK: u32 = 31;

const plic0: Plic = Plic{
    .base_addr = PLIC_CTRL_ADDR,
};
const uart0: Uart = Uart{
    .base_addr = UART0_CTRL_ADDR,
};
const uart1: Uart = Uart{
    .base_addr = UART1_CTRL_ADDR,
};

var stream = io.BufferedIO{
    .plic = plic0,
    .uart = uart0,
};

pub fn panic(msg: []const u8, error_return_trace: ?*StackTrace) noreturn {
    // copied from the default_panic implementation
    @setCold(true);

    const ustream = io.UnbufferedWriter.init(uart0);
    ustream.print("PANIC: {}\n", .{msg}) catch void;

    @breakpoint();
    while (true) {}
}

export fn level1IRQHandler() void {
    const mcause = asm ("csrr %[ret], mcause"
        : [ret] "=r" (-> u32)
    );

    if ((mcause >> MCAUSE_IRQ_MASK) != 1)
        @panic("unexpected trap"); // not an interrupt

    plic0.invokeHandler();
}

export fn init() void {
    // Threshold is not reset to zero by default.
    plic0.setThreshold(0);

    stream.init(UART0_IRQ) catch |err| {
        // TODO: emit error message
        @panic("could not initialize stream");
    };

    const smux = slipmux.SlipMux.init(uart1, plic0, UART1_IRQ);

    const in = stream.reader();
    const out = stream.writer();

    out.writeAll("Booting zig-riscv-embedded...\n") catch {
        @panic("writeAll failed");
    };

    return;
}
