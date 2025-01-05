const std = @import("std");
const assert = std.debug.assert;
const commandexec = @import("lib/commandline/commandexec.zig");
const CommandAdressingError = commandexec.CommandAdressingError;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args: []const [:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    std.debug.print("<DEBUG>\n\r", .{});
    for (args) |arg| {
        std.debug.print("{s}\n\r", .{arg});
    }
    std.debug.print("</DEBUG>\n\r\n\r", .{});

    commandexec.executePrintOutput(args);
}
