const std = @import("std");
const ICommand = @import("../ICommand.zig");
const CommandArgsError = @import("../clineerror.zig").CommandArgsError;
const IRparser = @import("../../parser/IRparser.zig");
const fileops = @import("../../file/fileops.zig");
const interpret = @import("../../interpreter/interpret.zig");
const SourceObject = @import("../../interpreter/SourceObject.zig");
const tape = &@import("../../interpreter/tape.zig").tape;

pub const melodify_command: ICommand = .{ .name = "melodify", .description = description, .execute = execute };

const description = "turns a soar source or IR file into whatever desired output is specified by that file";

fn execute(args: []const []const u8) CommandArgsError![]const u8 {
    if (args.len <= 2)
        return CommandArgsError.InvalidArgumentCount;

    const path = args[2];

    const source = fileops.readFile(path, std.heap.page_allocator) catch return "an unknown error occurred while opening file";
    var source_obj = SourceObject.construct(source, tape, std.heap.page_allocator) catch return "an unknown error occurred while constructing source object";

    interpret.interpretSourceObj(&source_obj) catch |err| return @errorName(err);

    return "exit code 0";
}
