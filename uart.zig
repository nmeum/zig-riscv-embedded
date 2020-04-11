// Offsets for memory mapped UART control registers.
const UART_REG_TXFIFO: u32 = 0x00;
const UART_REG_RXFIFO: u32 = 0x04;
const UART_REG_TXCTRL: u32 = 0x08;
const UART_REG_RXCTRL: u32 = 0x0c;
const UART_REG_IE: u32 = 0x10;
const UART_REG_IP: u32 = 0x14;
const UART_REG_DIV: u32 = 0x18;

// To-do
const UART_TX_WATERMARK: u32 = 1;
const UART_RX_WATERMARK: u32 = 1;

pub const UART = struct {
    base_addr: u32,
    irq: u32,

    pub const txctrl = packed struct {
        txen: bool,
        nstop: u1,
        _: u14 = 0, // reserved
        txcnt: u3,
        __: u13 = 0, // reserved
    };

    pub const rxctrl = packed struct {
        rxen: bool,
        _: u15 = 0, // reserved
        rxcnt: u3,
        __: u13 = 0, // reserved
    };

    pub const ie = packed struct {
        txwm: bool,
        rxwm: bool,
        _: u30 = 0, // reserved
    };

    fn write_word(self: UART, offset: u32, value: u32) void {
        const ptr = @intToPtr(*volatile u32, self.base_addr + offset);
        ptr.* = value;
    }

    pub fn writeTxctrl(self: UART, ctrl: txctrl) void {
        var serialized = @bitCast(u32, ctrl);
        self.write_word(UART_REG_TXCTRL, serialized);
    }

    pub fn writeRxctrl(self: UART, ctrl: rxctrl) void {
        var serialized = @bitCast(u32, ctrl);
        self.write_word(UART_REG_RXCTRL, serialized);
    }

    pub fn writeIe(self: UART, val: ie) void {
        var serialized = @bitCast(u32, val);
        self.write_word(UART_REG_IE, serialized);
    }

    pub fn write_byte(self: UART, value: u8) void {
        self.write_word(UART_REG_TXFIFO, value);
    }
};
