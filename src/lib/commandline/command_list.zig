const ICommand = @import("ICommand.zig");
const help_command = @import("commands/help_command.zig").help_command;
const derg_command = @import("commands/derg_command.zig").derg_command;
const melodify_command = @import("commands/melodify_command.zig").melodify_command;

pub const command_list = [_]ICommand{
    help_command,
    derg_command,
    melodify_command,
};
