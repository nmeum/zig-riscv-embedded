// Copyright © 2021 Sören Tempel
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

const console = @import("console.zig");
const slipmux = @import("slipmux.zig");
const periph = @import("periph.zig");
const zoap = @import("zoap");
const codes = zoap.codes;

const resources = &[_]zoap.Resource{
    .{ .path = "on", .handler = ledOn },
    .{ .path = "off", .handler = ledOff },
};
var dispatcher = zoap.Dispatcher{
    .resources = resources,
};

pub fn ledOn(resp: *zoap.Response, req: *zoap.Request) codes.Code {
    if (!req.header.code.equal(codes.PUT))
        return codes.BAD_REQ;

    console.print("[coap] Turning LED on\n", .{});
    periph.gpio0.set(periph.led0, 0);

    return codes.CREATED;
}

pub fn ledOff(resp: *zoap.Response, req: *zoap.Request) codes.Code {
    if (!req.header.code.equal(codes.PUT))
        return codes.BAD_REQ;

    console.print("[coap] Turning LED off\n", .{});
    periph.gpio0.set(periph.led0, 1);

    return codes.CREATED;
}

pub fn coapHandler(req: *zoap.Request) void {
    console.print("[coap] Incoming request\n", .{});
    var resp = dispatcher.dispatch(req) catch |err| {
        console.print("[coap] Dispatch failed: {s}\n", .{@errorName(err)});
        return;
    };

    const ftype = slipmux.FrameType.coap;
    var frame = periph.slipmux.newFrame(ftype);

    try frame.writer().writeAll(resp.marshal());
    frame.close();
}

pub fn main() !void {
    try periph.slipmux.registerHandler(coapHandler);
    console.print("Waiting for incoming CoAP packets over UART0...\n", .{});
}
