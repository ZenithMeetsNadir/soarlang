const ICommand = @import("ICommand.zig");
const help_command = @import("commands/helpcommand.zig").help_command;
const derg_command = @import("commands/dergcommand.zig").derg_command;

pub const command_list = [_]ICommand{
    help_command,
    derg_command,
};
