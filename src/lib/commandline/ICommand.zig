const CommandArgsError = @import("CLI_error.zig").CommandArgsError;

name: []const u8,
description: ?[]const u8,

execute: *const fn (args: []const []const u8) CommandArgsError![]const u8
