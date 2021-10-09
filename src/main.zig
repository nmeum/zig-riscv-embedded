// Copyright © 2021 Sören Tempel
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the
// Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
// Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program. If not, see <http://www.gnu.org/licenses/>.

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
