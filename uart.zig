// Offsets for memory mapped UART control registers.
const UART_REG_TXFIFO : u32 = 0x00;
const UART_REG_RXFIFO : u32 = 0x04;
const UART_REG_TXCTRL : u32 = 0x08;
const UART_REG_RXCTRL : u32 = 0x0c;
const UART_REG_IE     : u32 = 0x10;
const UART_REG_IP     : u32 = 0x14;
const UART_REG_DIV    : u32 = 0x18;

// To-do
const UART_TX_WATERMARK: u32 = 1;
const UART_RX_WATERMARK: u32 = 1;

pub const UART = struct {
    base_addr: u32,
    irq: u32,

    fn write_word(self: UART, offset: u32, value: u32) void {
        const ptr = @intToPtr(*volatile u32, self.base_addr + offset);
        ptr.* = value;
    }

    pub fn configure(self: UART) void {
        // Set TX and RX watermarks
        self.write_word(UART_REG_TXCTRL, (UART_TX_WATERMARK << 16));
        self.write_word(UART_REG_RXCTRL, (UART_RX_WATERMARK << 16));

        // Enable TX and disable RX interrupt
        self.write_word(UART_REG_IE, (1 << 0));
    }

    pub fn write_byte(self: UART, value: u8) void {
        self.write_word(UART_REG_TXFIFO, value);
    }
};
