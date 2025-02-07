const std = @import("std");
const fs = std.fs;
const IR_parser = @import("./IR_parser.zig");
const file_ops = @import("../file/file_ops.zig");

const FunctionTable = @This();

const FuncMap = std.StringHashMap(IR_parser.InstructionIterator);
const Resources = std.ArrayList([]const u8);

pub const FunctionTableError = error{
    AmbiguousName,
    UnnamedFunction,
    HashMapError,
};

pub const DllLinkError = error{
    PathNotFound,
    NotADll,
};

pub const FunctionGetError = error{
    UndefinedReference,
};

allocator: std.mem.Allocator,
func_map: FuncMap,
working_dir: fs.Dir = undefined,
included_dlls: std.BufSet,

resources: Resources,

pub fn construct(script_path: []const u8, allocator: std.mem.Allocator) file_ops.ParentDirError!FunctionTable {
    const working_dir = try fs.cwd().openDir(try file_ops.getParentDirPath(script_path), .{});
    return FunctionTable{ .allocator = allocator, .func_map = FuncMap.init(allocator), .working_dir = working_dir, .included_dlls = std.BufSet.init(allocator), .resources = Resources.init(allocator) };
}

pub fn dispose(self: *FunctionTable) void {
    self.func_map.deinit();
    self.included_dlls.deinit();

    for (self.resources.items) |resource| {
        self.allocator.free(resource);
    }

    self.resources.deinit();
    self.working_dir.close();
}

pub fn createFnTable(self: *FunctionTable, line_iter: *IR_parser.LineIterator) (DllLinkError || FunctionTableError)!void {
    try self.fnTableFromIter(line_iter);
}

pub fn linkDll(self: *FunctionTable, path: []const u8) (DllLinkError || FunctionTableError)!void {
    const source = file_ops.readFileFromDir(self.working_dir, path, self.allocator) catch return DllLinkError.PathNotFound;
    self.resources.append(source) catch return FunctionTableError.HashMapError;

    var line_iter = IR_parser.tokenize(source);
    var instr_iter = IR_parser.InstructionIterator.construct(line_iter);
    if (IR_parser.readLangConfig(&instr_iter).exec_type != .script)
        return DllLinkError.NotADll;

    try self.fnTableFromIter(&line_iter);
}

pub fn fnTableFromIter(self: *FunctionTable, line_iter: *IR_parser.LineIterator) (DllLinkError || FunctionTableError)!void {
    while (line_iter.next()) |line| {
        var line_mut = line;
        const instr_name = line_mut.first() orelse continue;

        if (std.mem.eql(u8, instr_name, "func")) {
            const func_name = line_mut.next() orelse return FunctionTableError.UnnamedFunction;

            if (self.func_map.get(func_name) != null)
                return FunctionTableError.AmbiguousName;

            const instr_iter = IR_parser.InstructionIterator.constructFuncBodyIterator(line_iter.*);
            self.func_map.putNoClobber(func_name, instr_iter) catch return FunctionTableError.HashMapError;
        } else if (std.mem.eql(u8, instr_name, "include")) {
            const path = line_mut.next() orelse continue;

            if (!self.included_dlls.contains(path)) {
                self.included_dlls.insert(path) catch return FunctionTableError.HashMapError;
                try self.linkDll(path);
            }
        }
    }
}
