const std = @import("std");
const ICommand = @import("../ICommand.zig");
const command_list = @import("../command_list.zig");
const CommandArgsError = @import("../CLI_error.zig").CommandArgsError;

pub const help_command: ICommand = .{ .name = "help", .description = "prints every existing command along with its brief description", .execute = execute };

fn execute(args: []const []const u8) CommandArgsError![]const u8 {
    if (args.len > 2)
        return CommandArgsError.InvalidArgumentCount;

    return help();
}

fn help() []const u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const output_allocator = std.heap.page_allocator;

    var lines: [command_list.command_list.len][]const u8 = undefined;

    for (command_list.command_list, 0..) |command, index| {
        const line = std.fmt.allocPrint(allocator, "\t{s}\t\t{s}\n\r", .{ command.name, command.description orelse "" }) catch return "";

        lines[index] = line;
    }

    return std.mem.concat(output_allocator, u8, &lines) catch return "";
}
