const std = @import("std");
const ICommand = @import("ICommand.zig");
const comandlist = @import("commandlist.zig");
const CommandAdressingError = @import("clineerror.zig").CommandAdressingError;
const help_command = @import("commands/helpcommand.zig").help_command;

fn executeCommand(args: []const []const u8) CommandAdressingError![]const u8 {
    if (args.len <= 1)
        return CommandAdressingError.NoCommandProvided;

    const command: ICommand = findCommand(args[1]) orelse return CommandAdressingError.UnknownCommand;

    return command.execute(args) catch "Either you fed me too few or too many arguments >,,<";
}

pub fn executePrintOutput(args: []const []const u8) void {
    const log = executeCommand(args) catch |err| blk: {
        break :blk switch (err) {
            CommandAdressingError.NoCommandProvided => help_command.execute(args) catch ">.< Oops! Help command failed, how may I help you?",
            CommandAdressingError.UnknownCommand => "Hate to say that, but no such command exists O'_o\n",
        };
    };

    std.debug.print("{s}", .{log});
}

pub fn find(comptime T: type, array: []T, predicate: fn (elem: T) bool) ?T {
    return for (array) |elem| {
        if (predicate(elem)) break elem;
    } else null;
}

fn findCommand(name: []const u8) ?ICommand {
    return for (comandlist.command_list) |command| {
        if (std.mem.eql(u8, command.name, name)) break command;
    } else null;
}
