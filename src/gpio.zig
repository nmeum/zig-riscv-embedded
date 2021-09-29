// Maximum of 32 pins -> 2**5 = 32.
pub const Pin = u5;

pub fn pin(x: Pin, y: Pin) Pin {
    return x | y;
}

pub const Gpio = struct {
    base_addr: usize,

    const Reg = enum(usize) {
        IOF_EN = 0x38,
        IOF_SEL = 0x3c,
    };

    fn readWord(self: Gpio, reg: Reg) u32 {
        const ptr = @intToPtr(*u32, self.base_addr + @enumToInt(reg));
        return ptr.*;
    }

    fn writeWord(self: Gpio, reg: Reg, value: u32) void {
        const ptr = @intToPtr(*volatile u32, self.base_addr + @enumToInt(reg));
        ptr.* = value;
    }

    // Configure a GPIO pin as IOF controlled (instead of software controlled).
    pub fn setIOFCtrl(self: Gpio, x: Pin, select: u1) void {
        const mask: u32 = @as(u32, 1) << x;

        // Select one of the two HW-Driven functions.
        const sel = self.readWord(Reg.IOF_SEL);
        if (select == 0) {
            self.writeWord(Reg.IOF_SEL, sel & ~mask);
        } else {
            self.writeWord(Reg.IOF_SEL, sel & mask);
        }

        // Enable selected HW-Driven function.
        const en = self.readWord(Reg.IOF_EN);
        self.writeWord(Reg.IOF_EN, en | mask);
    }
};
