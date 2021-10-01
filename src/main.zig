const console = @import("console.zig");
const slipmux = @import("slipmux.zig");
const periph = @import("periph.zig");
const zoap = @import("zoap");

const resources = &[_]zoap.res.Resource{
    .{ .path = "on", .handler = ledOn },
    .{ .path = "off", .handler = ledOff },
};
const dispatcher = zoap.res.Dispatcher{
    .resources = resources,
};

pub fn ledOn(pkt: *zoap.pkt.Packet) void {
    if (!pkt.header.code.equal(zoap.codes.PUT))
        return;

    console.print("[coap] Turning LED on\n", .{});
    periph.gpio0.set(periph.led0, 0);
}

pub fn ledOff(pkt: *zoap.pkt.Packet) void {
    if (!pkt.header.code.equal(zoap.codes.PUT))
        return;

    console.print("[coap] Turning LED off\n", .{});
    periph.gpio0.set(periph.led0, 1);
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
