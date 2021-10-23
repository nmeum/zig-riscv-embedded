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

const console = @import("console.zig");
const periph = @import("periph.zig");
const main = @import("main.zig");
const StackTrace = @import("std").builtin.StackTrace;

// Bitmasks for modifying mcause CSR
const MCAUSE_EXPCODE = 0x0fff;
const MCAUSE_INT = 0x80000000;

// Exception codes
const EXP_BREAKPOINT = 3;

pub fn panic(msg: []const u8, error_return_trace: ?*StackTrace) noreturn {
    // Copied from the default_panic implementation
    @setCold(true);

    // Write panic message, unbuffered to standard out
    console.print("PANIC: {s}\n", .{msg});

    @breakpoint();
    while (true) {}
}

export fn level1IRQHandler() void {
    const mcause = asm ("csrr %[ret], mcause"
        : [ret] "=r" (-> u32)
    );

    const expcode: u32 = mcause & MCAUSE_EXPCODE;
    if ((mcause & MCAUSE_INT) == MCAUSE_INT) {
        periph.plic0.invokeHandler();
    } else {
        if (expcode == EXP_BREAKPOINT) {
            while (true) {}
        }
        @panic("unexpected trap");
    }
}

export fn init() void {
    periph.init();
    console.print("Booting zig-riscv-embedded...\n", .{});

    main.main() catch |err| {
        @panic(@errorName(err));
    };
}
