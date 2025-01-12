const std = @import("std");
const IR_parser = @import("../parser/IR_parser.zig");
const Stack = @import("./Stack.zig");
const LangConfig = @import("./LangConfig.zig");

const SourceObject = @This();

pub const FunctionTable = std.StringHashMap(IR_parser.InstructionIterator);

pub const FunctionTableError = error{
    AmbiguousName,
    UnnamedFunction,
    HashMapError,
};

pub const FunctionGetError = error{
    DoesntExist,
};

source: []const u8,
lang_config: LangConfig = undefined,
stack: Stack,
instr_iter: IR_parser.InstructionIterator = undefined,
func_table: FunctionTable = undefined,
debug_enabled: bool = true,

pub fn construct(source: []const u8, stack: Stack, allocator: std.mem.Allocator) FunctionTableError!SourceObject {
    var source_obj = SourceObject{ .source = source, .stack = stack };
    var line_iter = IR_parser.tokenize(source);

    source_obj.instr_iter = IR_parser.InstructionIterator.construct(line_iter);
    source_obj.lang_config = IR_parser.readLangConfig(&source_obj.instr_iter);
    source_obj.func_table = try IR_parser.createFnTable(&line_iter, allocator);

    return source_obj;
}

pub fn dispose(self: SourceObject) void {
    IR_parser.destroyFnTable(self.func_table);
}

pub fn getFunc(self: SourceObject, func_name: []const u8) FunctionGetError!IR_parser.InstructionIterator {
    return self.func_table.get(func_name) orelse FunctionGetError.DoesntExist;
}
