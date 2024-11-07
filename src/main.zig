const std = @import("std");
const assert = std.debug.assert;
const execute = @import("lib/commandline/execute.zig");
const CommandAdressingError = execute.CommandAdressingError;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args: []const [:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const log = execute.executeCommand(args) catch |err| blk: {
        break :blk switch (err) {
            CommandAdressingError.NoCommandProvided => "error no command provided\n",
            CommandAdressingError.UnknownCommand => "no such command exists\n",
        };
    };

    std.debug.print("{s}", .{log});
}
