const ICommand = @import("../ICommand.zig");
const CommandArgsError = @import("../CLI_error.zig").CommandArgsError;

pub const derg_command: ICommand = .{ .name = "derg", .description = "possibly prints a dragon", .execute = execute };

fn execute(args: []const []const u8) CommandArgsError![]const u8 {
    _ = args;
    return "here be dragons\n\r";
}
