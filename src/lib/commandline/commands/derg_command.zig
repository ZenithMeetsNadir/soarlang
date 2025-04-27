const ICommand = @import("../ICommand.zig");
const CommandExecutionError = @import("../CLI_error.zig").CommandExecutionError;

pub const derg_command: ICommand = .{ .name = "derg", .description = "possibly prints a dragon", .execute = execute };

fn execute(args: []const []const u8) CommandExecutionError![]const u8 {
    _ = args;
    return "here be dragons\n";
}
