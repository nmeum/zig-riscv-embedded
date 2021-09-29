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

pub fn panic(msg: []const u8, error_return_trace: ?*StackTrace) noreturn {
    // Copied from the default_panic implementation
    @setCold(true);

    // Write panic message, unbuffered to standard out
    console.debug("PANIC: {}\n", .{msg});

    @breakpoint();
    while (true) {}
}

export fn level1IRQHandler() void {
    const mcause = asm ("csrr %[ret], mcause"
        : [ret] "=r" (-> u32)
    );

    const expcode: u32 = mcause & 0x0fff;
    if ((mcause >> 31) == 1) {
        periph.plic0.invokeHandler();
    } else {
        if (expcode == 3) { // breakpoint
            while (true) {}
        }
        @panic("unexpected trap"); // not an interrupt
    }
}

export fn init() void {
    periph.init();
    console.init() catch |err| {
        @panic(@errorName(err));
    };

    console.print("Booting zig-riscv-embedded...\n", .{});
    main.main() catch |err| {
        @panic(@errorName(err));
    };
}
