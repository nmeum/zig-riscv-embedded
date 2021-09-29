const io = @import("io.zig");
const periph = @import("periph.zig");

var buffered = io.BufferedIO{
    .plic = periph.plic0,
    .uart = periph.uart0,
};

var unbufferedWriter = io.UnbufferedWriter.init(periph.uart0);

// Write a message, unbuffered to standard output.
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    unbufferedWriter.print(fmt, args) catch return;
}

// Write a message, buffered to standard output.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    const w = buffered.writer();
    w.print(fmt, args) catch return;
}

pub fn init() !void {
    try buffered.init();
}
