const std = @import("std");
const IRparser = @import("../parser/IRparser.zig");
const Stack = @import("./Stack.zig");

const SourceObject = @This();

pub const FunctionTable = std.StringHashMap(IRparser.InstructionIterator);

pub const FunctionTableError = error{
    AmbiguousName,
    UnnamedFunction,
    HashMapError,
};

pub const FunctionGetError = error{
    DoesntExist,
};

source: []const u8,
stack: Stack,
instr_iter: IRparser.InstructionIterator = undefined,
func_table: FunctionTable = undefined,
debug_enabled: bool = true,

pub fn construct(source: []const u8, stack: Stack, allocator: std.mem.Allocator) FunctionTableError!SourceObject {
    var source_obj = SourceObject{ .source = source, .stack = stack };
    var line_iter = IRparser.tokenize(source);

    source_obj.instr_iter = IRparser.InstructionIterator.construct(line_iter);
    source_obj.func_table = try IRparser.createFnTable(&line_iter, allocator);

    return source_obj;
}

pub fn dispose(self: SourceObject) void {
    IRparser.destroyFnTable(self.func_table);
}

pub fn getFunc(self: SourceObject, func_name: []const u8) FunctionGetError!IRparser.InstructionIterator {
    return self.func_table.get(func_name) orelse FunctionGetError.DoesntExist;
}
