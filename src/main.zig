const std = @import("std");
const assert = std.debug.assert;
const command_exec = @import("lib/commandline/command_exec.zig");
const CommandAdressingError = command_exec.CommandAdressingError;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args: []const [:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    std.debug.print("<DEBUG>\n", .{});
    for (args) |arg| {
        std.debug.print("{s}\n", .{arg});
    }
    std.debug.print("</DEBUG>\n\n", .{});

    command_exec.executePrintOutput(args);
}
