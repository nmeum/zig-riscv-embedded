// UART control base addresses.
const UART0_CTRL_ADDR: u32 = 0x10013000;
const UART1_CTRL_ADDR: u32 = 0x10023000;

// Offsets for memory mapped UART control registers.
const UART_REG_TXFIFO : u32 = 0x00;
const UART_REG_RXFIFO : u32 = 0x04;
const UART_REG_TXCTRL : u32 = 0x08;
const UART_REG_RXCTRL : u32 = 0x0c;
const UART_REG_IE     : u32 = 0x10;
const UART_REG_IP     : u32 = 0x14;
const UART_REG_DIV    : u32 = 0x18;

export fn myinit() void {
    const uart0tx = @intToPtr(*volatile u32, UART0_CTRL_ADDR + UART_REG_TXFIFO);
    uart0tx.* = 'H';
    uart0tx.* = 'e';
    uart0tx.* = 'l';
    uart0tx.* = 'l';
    uart0tx.* = 'o';
    uart0tx.* = '!';
    uart0tx.* = '\n';
}
