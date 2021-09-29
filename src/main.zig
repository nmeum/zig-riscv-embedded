const console = @import("console.zig");

pub fn main() !void {
    const stdout = console.getStdOut().writer();
    try stdout.print("Hello, {s}!\n", .{"world"});
}
