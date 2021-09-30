const console = @import("console.zig");
const slipmux = @import("slipmux.zig");
const periph = @import("periph.zig");
const zoap = @import("zoap");

var smux = slipmux.SlipMux{
    .handler = coapHandler,
};

const resources = &[_]zoap.res.Resource{
    .{ .path = "panic", .handler = panicHandler },
};
const dispatcher = zoap.res.Dispatcher{
    .resources = resources,
};

pub fn panicHandler(pkt: *zoap.pkt.Packet) void {
    if (!pkt.header.code.equal(zoap.pkt.codes.PUT))
        return;

    @panic("User requested a panic!");
}

pub fn coapHandler(pkt: *zoap.pkt.Packet) void {
    console.debug("[coap] Incoming request\n", .{});
    const ret = dispatcher.dispatch(pkt) catch |err| {
        console.debug("[coap] Dispatch failed: {}\n", .{@errorName(err)});
        return;
    };

    if (!ret)
        console.debug("[coap] Request to unknown resource\n", .{});
}

pub fn main() !void {
    try smux.init(periph.uart1, periph.plic0);
    console.print("Waiting for incoming CoAP packets over UART1...\n", .{});
}
