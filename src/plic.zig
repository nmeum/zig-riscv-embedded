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
pub const Handler = fn (args: ?*c_void) void;

pub const Plic = struct {
    base_addr: usize,

    // TODO: Get rid of c_void in the long run.
    var irq_handlers: [INTERRUPT_SOURCES]?Handler = undefined;
    var irq_contexts: [INTERRUPT_SOURCES]?*c_void = undefined;

    pub fn setThreshold(self: Plic, threshold: u3) void {
        const plic_thres = @intToPtr(*volatile u32, PLIC_CTRL_ADDR + PLIC_CONTEXT_OFF);
        plic_thres.* = threshold;
    }

    fn setPriority(self: Plic, irq: Irq, prio: u3) void {
        // Set PLIC priority for IRQ
        const plic_prio = @intToPtr(*volatile u32, PLIC_CTRL_ADDR +
            PLIC_PRIO_OFF + (@as(u32, irq) * @sizeOf(u32)));
        plic_prio.* = @as(u32, prio);
    }

    fn setEnable(self: Plic, irq: Irq, enable: bool) void {
        const idx = irq / 32;

        const enable_addr: usize = PLIC_CTRL_ADDR + PLIC_ENABLE_OFF;
        const plic_enable = @intToPtr(*volatile u32, enable_addr + (idx * @sizeOf(u32)));

        const off = @intCast(u5, irq % 32);
        if (enable) {
            plic_enable.* |= @intCast(u32, 1) << off;
        } else {
            plic_enable.* &= ~(@intCast(u32, 1) << off);
        }
    }

    pub fn registerHandler(self: Plic, irq: Irq, func: Handler, ctx: ?*c_void) !void {
        if (irq >= irq_handlers.len)
            return error.OutOfBounds;

        irq_handlers[irq] = func;
        irq_contexts[irq] = ctx;

        self.setPriority(irq, 1);
        self.setEnable(irq, true);
    }

    pub fn invokeHandler(self: Plic) void {
        const claim_reg = @intToPtr(*volatile u32, PLIC_CTRL_ADDR + PLIC_CONTEXT_OFF + @sizeOf(u32));
        const irq = @intCast(Irq, claim_reg.*);

        if (irq_handlers[irq]) |handler|
            handler(irq_contexts[irq]);

        // Mark interrupt as completed
        claim_reg.* = irq;
    }

    pub fn init(self: Plic) void {
        // Threshold is uninitialized by default.
        self.setThreshold(0);

        var i: Irq = 1;
        while (i <= INTERRUPT_SOURCES) : (i += 1) {
            self.setEnable(i, false);
            self.setPriority(i, 0);
        }
    }
};
