const periph = @import("periph.zig");
const slipmux = @import("slipmux.zig");

pub fn getStdDbg() slipmux.Frame {
    const ftype = slipmux.SlipMux.FrameType.diagnostic;
    return periph.slipmux.newFrame(ftype);
}

// Write a Slipmux diagnostic message, unbuffered, to the UART.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    const stddbg = getStdDbg();
    defer stddbg.close();

    const w = stddbg.writer();
    nosuspend w.print(fmt, args) catch return;
}
