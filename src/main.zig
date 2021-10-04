const console = @import("console.zig");
const slipmux = @import("slipmux.zig");
const periph = @import("periph.zig");
const zoap = @import("zoap");

const resources = &[_]zoap.res.Resource{
    .{ .path = "panic", .handler = panicHandler },
};
const dispatcher = zoap.res.Dispatcher{
    .resources = resources,
};

pub fn panicHandler(pkt: *zoap.pkt.Packet) void {
    if (!pkt.header.code.equal(zoap.codes.PUT))
        return;

    @panic("User requested a panic!");
}

pub fn coapHandler(pkt: *zoap.pkt.Packet) void {
    console.print("[coap] Incoming request\n", .{});
    const ret = dispatcher.dispatch(pkt) catch |err| {
        console.print("[coap] Dispatch failed: {}\n", .{@errorName(err)});
        return;
    };

    if (!ret)
        console.print("[coap] Request to unknown resource\n", .{});
}

pub fn main() !void {
    try periph.slipmux.registerHandler(coapHandler);
    console.print("Waiting for incoming CoAP packets over UART0...\n", .{});
}
