const std = @import("std");
const file_ops = @import("../file/file_ops.zig");
const IR_parser = @import("../parser/IR_parser.zig");
const Stack = @import("./Stack.zig");
const LangConfig = @import("./LangConfig.zig");
const FunctionTable = @import("../parser/FunctionTable.zig");

const SourceObject = @This();

source: []const u8,
lang_config: LangConfig,
stack: Stack,
line_iter: IR_parser.LineIterator,
instr_iter: IR_parser.InstructionIterator,
func_table: FunctionTable,
path: []const u8,
debug_enabled: bool = true,

pub fn construct(source: []const u8, stack: Stack, path: []const u8, allocator: std.mem.Allocator) file_ops.ParentDirError!SourceObject {
    const line_iter = IR_parser.tokenize(source);
    var instr_iter = IR_parser.InstructionIterator.construct(line_iter);
    const func_table = try FunctionTable.construct(path, allocator);

    return SourceObject{ .source = source, .lang_config = IR_parser.readLangConfig(&instr_iter), .stack = stack, .line_iter = line_iter, .instr_iter = instr_iter, .func_table = func_table, .path = path };
}

pub fn createFnTable(self: *SourceObject) (FunctionTable.DllLinkError || FunctionTable.FunctionTableError)!void {
    try self.func_table.createFnTable(&self.line_iter);
}

pub fn dispose(self: *SourceObject) void {
    self.func_table.dispose();
}

pub fn getFunc(self: SourceObject, func_name: []const u8) FunctionTable.FunctionGetError!IR_parser.InstructionIterator {
    return self.func_table.func_map.get(func_name) orelse FunctionTable.FunctionGetError.UndefinedReference;
}
