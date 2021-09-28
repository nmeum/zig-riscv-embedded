pub const IOF_EN: usize = 0x38;
pub const IOF_SEL: usize = 0x3C;

// Maximum of 32 pins -> 2**5 = 32.
pub const Pin = u5;

pub fn pin(x: Pin, y: Pin) Pin {
    return x|y;
}

pub const Gpio = struct {
    base_addr: usize,

    pub fn readWord(self: Gpio, offset: usize) u32 {
        const ptr = @intToPtr(*u32, self.base_addr + offset);
        return ptr.*;
    }

    pub fn writeWord(self: Gpio, offset: usize, value: u32) void {
        const ptr = @intToPtr(*volatile u32, self.base_addr + offset);
        ptr.* = value;
    }
};
