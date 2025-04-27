const CommandExecutionError = @import("CLI_error.zig").CommandExecutionError;

name: []const u8,
description: ?[]const u8,

execute: *const fn (args: []const []const u8) CommandExecutionError![]const u8
