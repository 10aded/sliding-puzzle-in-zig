const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    
    try stdout.writeAll("Type your name\n");
    var buffer: [20]u8 = undefined;
    @memset(buffer[0..], 0);
    _ = try stdin.readUntilDelimiterOrEof(buffer[0..], '\n');
//    _ = try stdin.streamUntilDelimiter(buffer[0..], '\n', 20);
    try stdout.print("Your name is: {s}\n", .{buffer});
}
