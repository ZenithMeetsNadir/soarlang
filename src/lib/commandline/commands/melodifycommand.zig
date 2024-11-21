const std = @import("std");
const ICommand = @import("../ICommand.zig");
const CommandArgsError = @import("../clineerror.zig").CommandArgsError;
const IRparser = @import("../../parser/IRparser.zig");
const fileops = @import("../../file/fileops.zig");

pub const melodify_command: ICommand = .{ .name = "melodify", .description = description, .execute = execute };

const description = "turns a soar source or IR file into whatever desired output is specified by that file";

fn execute(args: []const []const u8) CommandArgsError![]const u8 {
    if (args.len <= 2)
        return CommandArgsError.InvalidArgumentCount;

    const path = args[2];

    const source = fileops.readFile(path, std.heap.page_allocator) catch return "an unknown error occured while opening file";

    var source_iter = IRparser.tokenize(source);

    while (source_iter.next()) |*line| {
        var cpy = line.*;
        while (cpy.next()) |word| {
            std.debug.print("{s} ", .{word});
        }
    }

    @import("../../interpreter/tape.zig").tape[656] = '!';

    return "";
}
