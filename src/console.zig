const io = @import("io.zig");
const periph = @import("periph.zig");

var stdout = io.BufferedIO{
    .plic = periph.plic0,
    .uart = periph.uart0,
};

pub fn getStdOut() io.BufferedIO {
    return stdout;
}

// Write a debug message, unbuffered to standard output.
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    const w = stdout.writer();
    w.print(fmt, args) catch return;
}

pub fn init() void {
    stdout.init() catch |err| {
        @panic(@errorName(err));
    };
}
