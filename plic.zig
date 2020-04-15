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

// Offsets for memory mapped PLIC control registers.
const PLIC_CTRL_ADDR: usize = 0x0C000000;
const PLIC_PRIO_OFF: usize = 0x0000;
const PLIC_PENDING_OFF: usize = 0x1000;
const PLIC_ENABLE_OFF: usize = 0x2000;
const PLIC_CONTEXT_OFF: usize = 0x200000;

const INTERRUPT_SOURCES: Irq = 52;

// Type alias for IRQ values, largest possible IRQ on the FE310 is
// 52 (see INTERRUPT_SOURCES above), thus representable by a u6.
pub const Irq = u6;

// Type alias for PLIC interrupt handler functions.
pub const Handler = fn () void;

pub const Plic = struct {
    base_addr: usize,

    var irq_handlers: [INTERRUPT_SOURCES]?Handler = undefined;

    pub fn setThreshold(self: Plic, threshold: u3) void {
        const plic_thres = @intToPtr(*volatile u32, PLIC_CTRL_ADDR + PLIC_CONTEXT_OFF);
        plic_thres.* = threshold;
    }

    pub fn registerHandler(self: Plic, irq: Irq, handler: Handler) !void {
        if (irq >= irq_handlers.len)
            return error.OutOfBounds;
        irq_handlers[irq] = handler;

        // Set PLIC priority for IRQ
        const plic_prio = @intToPtr(*volatile u32, PLIC_CTRL_ADDR +
            PLIC_PRIO_OFF + (irq * @sizeOf(u32)));
        plic_prio.* = 1;

        // Enable interrupts for IRQ
        const enable_addr: u32 = PLIC_CTRL_ADDR + PLIC_ENABLE_OFF;
        const idx = irq / 32;
        const off = @intCast(u5, irq % 32);
        const plic_enable = @intToPtr(*volatile u32, enable_addr + idx);
        plic_enable.* = @intCast(u32, 1) << off;
    }

    pub fn invokeHandler(self: Plic) void {
        const claim_reg = @intToPtr(*volatile u32, PLIC_CTRL_ADDR + PLIC_CONTEXT_OFF + @sizeOf(u32));
        const irq = @intCast(Irq, claim_reg.*);

        if (irq_handlers[irq]) |handler|
            handler();

        // Mark interrupt as completed
        claim_reg.* = irq;
    }
};
