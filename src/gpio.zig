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
        INPUT_EN = 0x04,
        OUTPUT_EN = 0x08,
        OUTPUT_VAL = 0x0c,
        PUE = 0x10,
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
        self.setRegister(Reg.IOF_SEL, x, select);

        // Enable selected HW-Driven function.
        self.setRegister(Reg.IOF_EN, x, 1);
    }

    pub fn set(self: Gpio, x: Pin, v: u1) void {
        self.setRegister(Reg.OUTPUT_VAL, x, v);
    }

    pub fn init(self: Gpio, x: Pin, mode: Mode) void {
        switch (mode) {
            Mode.IN => {
                self.setRegister(Reg.INPUT_EN, x, 1);
                self.setRegister(Reg.OUTPUT_EN, x, 0);
                self.setRegister(Reg.PUE, x, 0);
            },
            Mode.OUT => {
                self.setRegister(Reg.INPUT_EN, x, 0);
                self.setRegister(Reg.OUTPUT_EN, x, 1);
                self.setRegister(Reg.PUE, x, 0);
            },
        }

        // Disable HW-driven functions for Pin
        self.setRegister(Reg.IOF_EN, x, 0);
        self.setRegister(Reg.IOF_SEL, x, 0);
    }
};
