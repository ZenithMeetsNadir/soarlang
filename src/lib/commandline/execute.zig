const std = @import("std");
const ICommand = @import("ICommand.zig");
const comandlist = @import("commandlist.zig");

pub const CommandAdressingError = error{
    NoCommandProvided,
    UnknownCommand,
};

pub const CommandArgsError = error{
    InvalidArgumentCount,
};

pub fn executeCommand(args: []const []const u8) CommandAdressingError![]const u8 {
    if (args.len <= 1)
        return CommandAdressingError.NoCommandProvided;

    const command: ICommand = findCommand(args[1]) orelse return CommandAdressingError.UnknownCommand;

    return command.execute(args) catch "wrong number of arguments";
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
