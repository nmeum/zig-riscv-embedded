const console = @import("console.zig");
const slipmux = @import("slipmux.zig");
const periph = @import("periph.zig");

pub fn main() !void {
    const smux = slipmux.SlipMux.init(periph.uart1, periph.plic0);
    console.print("Waiting for incoming CoAP packets over UART1...\n", .{});
}
