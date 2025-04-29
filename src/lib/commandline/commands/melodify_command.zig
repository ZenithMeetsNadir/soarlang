const std = @import("std");
const ICommand = @import("../ICommand.zig");
const CommandExecutionError = @import("../CLI_error.zig").CommandExecutionError;
const IR_parser = @import("../../parser/IR_parser.zig");
const flag_parser = @import("../flag_parser.zig");
const file_ops = @import("../../file/file_ops.zig");
const InterpretContext = @import("../../interpreter/InterpretContext.zig");
const InterpretError = InterpretContext.InterpretError;
const SourceObject = @import("../../interpreter/SourceObject.zig");
const Stack = @import("../../interpreter/Stack.zig");
const IRParseLog = @import("../../parser/logger.zig").IRParseLog;
const IpretLog = @import("../../interpreter/logger.zig").IpretLog;
const FunctionTableLog = @import("../../parser/logger.zig").FunctionTableLog;

pub const melodify_command: ICommand = .{ .name = "melodify", .description = description, .execute = execute };

const description = "turns a soar source or IR file into whatever desired output is specified by that file or flags on this command";

fn execute(args: []const []const u8) CommandExecutionError![]const u8 {
    if (args.len <= 2)
        return CommandExecutionError.InvalidArgumentCount;

    const path = args[2];

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const source = file_ops.readFile(path, allocator) catch |err| return @errorName(err);
    defer allocator.free(source);

    std.log.info("Constructing source object...", .{});
    var source_obj = SourceObject.construct(args, source, path, allocator) catch |err| {
        std.log.info("Failed to construct source object: {s}", .{@errorName(err)});
        return CommandExecutionError.ExecutionFailed;
    };
    defer source_obj.dispose();
    std.log.info("Source object successfully constructed", .{});

    std.log.info("Picking up workflow...", .{});
    try configureInterpret(&source_obj);

    return "exit code 0";
}

fn configureInterpret(source_obj: *SourceObject) CommandExecutionError!void {
    switch (source_obj.lang_config.language) {
        .soar_IR => {
            FunctionTableLog.info("Creating function table...", .{});
            source_obj.createFnTable() catch |err| {
                FunctionTableLog.err("Failed to create function table: {s}", .{@errorName(err)});
                return CommandExecutionError.ExecutionFailed;
            };
            //defer source_obj.func_table.dispose();
            FunctionTableLog.info("Function table successfully created", .{});

            var ipret_ctx = InterpretContext{ .source_obj = source_obj };

            // turn on debug mode(s)
            if (flag_parser.containsFlag(source_obj.invoke_args, "-d")) {
                ipret_ctx.debug_interpret_proc = flag_parser.containsFlag(source_obj.invoke_args, "--ipretproc");
                ipret_ctx.debug_visual_stack = flag_parser.containsFlag(source_obj.invoke_args, "--vsstack");
            }

            IpretLog.info("Feeding up interpreter...", .{});
            ipret_ctx.interpret(&source_obj.instr_iter) catch |err| switch (err) {
                InterpretError.ExecutionAborted => {
                    IpretLog.info("Execution intentionally aborted", .{});
                },
                else => {
                    IpretLog.err("Interpreter shut down: {s}", .{@errorName(err)});
                    return CommandExecutionError.ExecutionFailed;
                },
            };
            IpretLog.info("Interpreter shut down after successful execution", .{});
        },
        .soar_hlvl => std.log.err("soar_hlvl compiler is currently being developed", .{}),
    }
}
