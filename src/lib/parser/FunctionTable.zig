const std = @import("std");
const fs = std.fs;
const IR_parser = @import("./IR_parser.zig");
const file_ops = @import("../file/file_ops.zig");
const FunctionTableLog = @import("./logger.zig").FunctionTableLog;

const FunctionTable = @This();

const FuncMap = std.StringHashMap(IR_parser.InstructionIterator);
const AliasDict = std.StringHashMap([]const u8);
const Resources = std.StringHashMap([]const u8);

pub const FunctionTableError = error{
    AmbiguousName,
    AmbiguousAlias,
    NoRootForAlias,
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
working_dir: fs.Dir = undefined,
func_map: FuncMap,
resources: Resources,
alias_dict: AliasDict,

pub fn construct(script_path: []const u8, allocator: std.mem.Allocator) file_ops.ParentDirError!FunctionTable {
    const parent_dir_path = try file_ops.getParentDirPath(script_path);
    const working_dir = fs.cwd().openDir(parent_dir_path, .{}) catch return file_ops.ParentDirError.PathNotFound;
    FunctionTableLog.debug("parent_dir_path: {s}", .{parent_dir_path});
    return FunctionTable{ .allocator = allocator, .func_map = FuncMap.init(allocator), .working_dir = working_dir, .resources = Resources.init(allocator), .alias_dict = AliasDict.init(allocator) };
}

pub fn dispose(self: *FunctionTable) void {
    // all the keys of func_map are freed by freeing all the keys of alias_dict
    self.func_map.deinit();

    var resources_iter = self.resources.iterator();
    while (resources_iter.next()) |resource| {
        self.allocator.free(resource.value_ptr.*);
    }

    self.resources.deinit();

    var alias_iter = self.alias_dict.iterator();
    while (alias_iter.next()) |alias| {
        self.allocator.free(alias.key_ptr.*);
    }

    self.alias_dict.deinit();

    self.working_dir.close();
}

pub fn getFunc(self: FunctionTable, func_name: []const u8) FunctionGetError!IR_parser.InstructionIterator {
    return self.func_map.get(func_name) orelse blk: {
        const alias = self.alias_dict.get(func_name) orelse return FunctionGetError.UndefinedReference;
        break :blk self.func_map.get(alias) orelse return FunctionGetError.UndefinedReference;
    };
}

pub fn createFnTable(self: *FunctionTable, line_iter: *IR_parser.LineIterator) (DllLinkError || FunctionTableError)!void {
    try self.fnTableFromIter(line_iter, null, null, false);
}

pub fn linkDll(self: *FunctionTable, path: []const u8, alias: []const u8) (DllLinkError || FunctionTableError)!void {
    const get_or_put = self.resources.getOrPut(path) catch return FunctionTableError.HashMapError;
    if (!get_or_put.found_existing)
        get_or_put.value_ptr.* = file_ops.readFileFromDir(self.working_dir, path, self.allocator) catch return DllLinkError.PathNotFound;

    const source: []const u8 = get_or_put.value_ptr.*;

    var line_iter = IR_parser.tokenize(source);
    var instr_iter = IR_parser.InstructionIterator.construct(line_iter);
    if (IR_parser.readLangConfig(&instr_iter).exec_type != .dll)
        return DllLinkError.NotADll;

    FunctionTableLog.debug("found_existing: {any}", .{get_or_put.found_existing});
    if (!get_or_put.found_existing) {
        var line_iter_cpy = line_iter;
        try self.fnTableFromIter(&line_iter_cpy, path, null, false);
    }

    try self.fnTableFromIter(&line_iter, alias, path, true);
}

pub fn fnTableFromIter(self: *FunctionTable, line_iter: *IR_parser.LineIterator, alias: ?[]const u8, root_alias: ?[]const u8, shadow: bool) (DllLinkError || FunctionTableError)!void {
    while (line_iter.next()) |line| {
        var line_mut = line;
        const instr_name = line_mut.first() orelse continue;

        if (std.mem.eql(u8, instr_name, IR_parser.func_start)) {
            const func_name = line_mut.next() orelse return FunctionTableError.UnnamedFunction;

            const slices: []const []const u8 = if (alias) |alias_set| &[_][]const u8{ alias_set, func_name } else &[_][]const u8{func_name};
            const func_name_alias = std.mem.join(self.allocator, "/", slices) catch return FunctionTableError.HashMapError;
            errdefer self.allocator.free(func_name_alias);
            FunctionTableLog.debug("func_name_alias: {s}", .{func_name_alias});

            const root_slices: []const []const u8 = if (root_alias) |root_alias_set| &[_][]const u8{ root_alias_set, func_name } else &[_][]const u8{func_name_alias};
            const func_root_name = std.mem.join(self.allocator, "/", root_slices) catch return FunctionTableError.HashMapError;
            defer self.allocator.free(func_root_name);
            FunctionTableLog.debug("func_root_name: {s}", .{func_root_name});

            if (shadow) {
                const root_entry = self.alias_dict.getEntry(func_root_name) orelse return FunctionTableError.NoRootForAlias;
                const func_root_alloc = root_entry.key_ptr.*;

                if (!std.mem.eql(u8, func_name_alias, func_root_name)) {
                    if (self.alias_dict.get(func_name_alias) != null)
                        return FunctionTableError.AmbiguousAlias;

                    self.alias_dict.putNoClobber(func_name_alias, func_root_alloc) catch return FunctionTableError.HashMapError;
                } else self.allocator.free(func_name_alias);
            } else {
                if (self.func_map.get(func_name_alias) != null)
                    return FunctionTableError.AmbiguousName;

                const instr_iter = IR_parser.InstructionIterator.constructFuncBodyIterator(line_iter.*);
                self.func_map.putNoClobber(func_name_alias, instr_iter) catch return FunctionTableError.HashMapError;

                if (self.alias_dict.get(func_name_alias) != null)
                    return FunctionTableError.AmbiguousAlias;

                self.alias_dict.putNoClobber(func_name_alias, func_name) catch return FunctionTableError.HashMapError;
            }
        } else if (std.mem.eql(u8, instr_name, IR_parser.include_dll) and !shadow) {
            const path = line_mut.next() orelse continue;
            const include_alias = line_mut.next() orelse path;
            const alias_pure = IR_parser.purifyStrLiteral(include_alias, self.allocator) catch return FunctionTableError.HashMapError;
            defer alias_pure.dispose();

            std.debug.print("\n", .{});
            FunctionTableLog.debug("include_alias: {s}", .{include_alias});

            try self.linkDll(path, alias_pure.str());
        }
    }
}
