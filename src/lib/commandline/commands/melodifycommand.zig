const std = @import("std");
const ICommand = @import("../ICommand.zig");
const CommandArgsError = @import("../clineerror.zig").CommandArgsError;
const IRparser = @import("../../parser/IRparser.zig");
const flagparser = @import("../flagparser.zig");
const fileops = @import("../../file/fileops.zig");
const interpret = @import("../../interpreter/interpret.zig");
const InterpretError = interpret.InterpretError;
const SourceObject = @import("../../interpreter/SourceObject.zig");
const Stack = @import("../../interpreter/Stack.zig");

pub const melodify_command: ICommand = .{ .name = "melodify", .description = description, .execute = execute };

const description = "turns a soar source or IR file into whatever desired output is specified by that file";

fn execute(args: []const []const u8) CommandArgsError![]const u8 {
    if (args.len <= 2)
        return CommandArgsError.InvalidArgumentCount;

    if (flagparser.containsFlag(args, "-d")) {
        if (flagparser.containsFlag(args, "--ipretproc")) {
            interpret.debug_interpret_proc = true;
        }
        if (flagparser.containsFlag(args, "--vsstack")) {
            interpret.debug_visual_stack = true;
        }
    }

    const path = args[2];

    const source = fileops.readFile(path, std.heap.page_allocator) catch |err| return @errorName(err);
    const stack = Stack{ .stack_tape = &Stack.main_tape };
    var source_obj = SourceObject.construct(source, stack, std.heap.page_allocator) catch |err| return @errorName(err);

    return configureInterpret(&source_obj) catch |err| return @errorName(err);
}

fn configureInterpret(source_obj: *SourceObject) InterpretError![]const u8 {
    switch (source_obj.lang_config.language) {
        .soar_IR => {
            try interpret.interpretSourceObj(source_obj);
            return "soar_IR interpreter exit code 0";
        },
        .soar_hlvl => return "soar high level language compiler is currently being developed...",
    }
}
