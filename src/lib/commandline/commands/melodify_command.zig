const std = @import("std");
const ICommand = @import("../ICommand.zig");
const CommandArgsError = @import("../CLI_error.zig").CommandArgsError;
const IR_parser = @import("../../parser/IR_parser.zig");
const flag_parser = @import("../flag_parser.zig");
const file_ops = @import("../../file/file_ops.zig");
const InterpretContext = @import("../../interpreter/InterpretContext.zig");
const InterpretError = InterpretContext.InterpretError;
const SourceObject = @import("../../interpreter/SourceObject.zig");
const Stack = @import("../../interpreter/Stack.zig");

pub const melodify_command: ICommand = .{ .name = "melodify", .description = description, .execute = execute };

const description = "turns a soar source or IR file into whatever desired output is specified by that file or flags on this command";

fn execute(args: []const []const u8) CommandArgsError![]const u8 {
    if (args.len <= 2)
        return CommandArgsError.InvalidArgumentCount;

    const path = args[2];

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const source = file_ops.readFile(path, allocator) catch |err| return @errorName(err);
    defer allocator.free(source);

    var source_obj = SourceObject.construct(args, source, path, allocator) catch |err| return @errorName(err);
    defer source_obj.dispose();

    source_obj.createFnTable() catch |err| return @errorName(err);

    return configureInterpret(&source_obj) catch |err| return @errorName(err);
}

fn configureInterpret(source_obj: *SourceObject) InterpretError![]const u8 {
    switch (source_obj.lang_config.language) {
        .soar_IR => {
            var ipret_ctx = InterpretContext{ .source_obj = source_obj };

            // turn on debug mode(s)
            if (flag_parser.containsFlag(source_obj.invoke_args, "-d")) {
                ipret_ctx.debug_interpret_proc = flag_parser.containsFlag(source_obj.invoke_args, "--ipretproc");
                ipret_ctx.debug_visual_stack = flag_parser.containsFlag(source_obj.invoke_args, "--vsstack");
            }

            try ipret_ctx.interpret(&source_obj.instr_iter);
            return "soar_IR interpreter exit code 0";
        },
        .soar_hlvl => return "soar high level language compiler is currently being developed...",
    }
}
