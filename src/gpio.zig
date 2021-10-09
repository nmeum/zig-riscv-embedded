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

// Maximum of 32 pins -> 2**5 = 32.
pub const Pin = u5;

pub const Mode = enum {
    IN,
    OUT,
};

pub fn pin(x: Pin, y: Pin) Pin {
    return x | y;
}

pub const Gpio = struct {
    base_addr: usize,

    const Reg = enum(usize) {
        input = 0x04,
        output_en = 0x08,
        output_val = 0x0c,
        pue = 0x10,
        iof_en = 0x38,
        iof_sel = 0x3c,
    };

    fn readWord(self: Gpio, reg: Reg) u32 {
        const ptr = @intToPtr(*u32, self.base_addr + @enumToInt(reg));
        return ptr.*;
    }

    fn writeWord(self: Gpio, reg: Reg, value: u32) void {
        const ptr = @intToPtr(*volatile u32, self.base_addr + @enumToInt(reg));
        ptr.* = value;
    }

    pub fn setRegister(self: Gpio, reg: Reg, x: Pin, val: u1) void {
        const regVal = self.readWord(reg);

        const mask = @as(u32, 1) << x;
        if (val == 0) {
            self.writeWord(reg, regVal & ~mask);
        } else {
            self.writeWord(reg, regVal | mask);
        }
    }

    // Configure a GPIO pin as IOF controlled (instead of software controlled).
    pub fn setIOFCtrl(self: Gpio, x: Pin, select: u1) void {
        // Select one of the two HW-Driven functions.
        self.setRegister(Reg.iof_sel, x, select);

        // Enable selected HW-Driven function.
        self.setRegister(Reg.iof_en, x, 1);
    }

    pub fn set(self: Gpio, x: Pin, v: u1) void {
        self.setRegister(Reg.output_val, x, v);
    }

    pub fn init(self: Gpio, x: Pin, mode: Mode) void {
        switch (mode) {
            Mode.IN => {
                self.setRegister(Reg.input, x, 1);
                self.setRegister(Reg.output_en, x, 0);
                self.setRegister(Reg.pue, x, 0);
            },
            Mode.OUT => {
                self.setRegister(Reg.input, x, 0);
                self.setRegister(Reg.output_en, x, 1);
                self.setRegister(Reg.pue, x, 0);
            },
        }

        // Disable HW-driven functions for Pin
        self.setRegister(Reg.iof_en, x, 0);
        self.setRegister(Reg.iof_sel, x, 0);
    }
};
