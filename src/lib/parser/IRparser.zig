const std = @import("std");
const SourceObject = @import("../interpreter/SourceObject.zig");
const FunctionTable = SourceObject.FunctionTable;
const FunctionTableError = SourceObject.FunctionTableError;

pub fn sepatareLines(source: []const u8) std.mem.SplitIterator(u8, .any) {
    return std.mem.splitAny(u8, source, "\r\n");
}

pub const ArgumentIterator = struct {
    line_iter: std.mem.SplitIterator(u8, .any),

    fn isValid(word: []const u8) bool {
        return word.len > 0;
    }

    pub fn next(self: *ArgumentIterator) ?[]const u8 {
        return while (self.line_iter.next()) |word| {
            if (isValid(word))
                break word;
        } else null;
    }

    pub fn peek(self: ArgumentIterator) ?[]const u8 {
        var line_iter = self.line_iter;
        return while (line_iter.next()) |word| {
            if (isValid(word))
                break word;
        } else null;
    }

    pub fn first(self: *ArgumentIterator) ?[]const u8 {
        self.line_iter.index = 0;
        return self.next();
    }
};

pub const InstructionIterator = struct {
    line_iter: LineIterator,
    is_func: bool = false,
    inside_func_body: bool = false,

    pub fn construct(line_iter: LineIterator) InstructionIterator {
        return InstructionIterator{ .line_iter = line_iter };
    }

    pub fn constructFuncBodyIterator(line_iter: LineIterator) InstructionIterator {
        return InstructionIterator{ .line_iter = line_iter, .is_func = true, .inside_func_body = true };
    }

    pub fn next(self: *InstructionIterator) ?ArgumentIterator {
        return while (self.line_iter.next()) |instr| {
            if (self.inside_func_body and !self.is_func)
                break null;

            var instr_cpy = instr;
            const instr_name = instr_cpy.first() orelse continue;

            if (!self.is_func) {
                if (std.mem.eql(u8, instr_name, "FUNC")) {
                    self.is_func = true;
                    continue;
                }
            } else {
                if (std.mem.eql(u8, instr_name, "ENDFUNC")) {
                    if (self.inside_func_body)
                        break null;

                    self.is_func = false;
                }

                if (!self.inside_func_body)
                    continue;
            }

            break instr;
        } else null;
    }
};

pub const LineIterator = struct {
    source_iter: std.mem.SplitIterator(u8, .any),

    pub fn next(self: *LineIterator) ?ArgumentIterator {
        return while (self.source_iter.next()) |line| {
            if (line.len > 0)
                break splitLine(line);
        } else null;
    }
};

pub fn splitLine(line: []const u8) ArgumentIterator {
    var line_iter = std.mem.splitScalar(u8, line, ';');
    const wo_comments = line_iter.first();

    return ArgumentIterator{ .line_iter = std.mem.splitAny(u8, wo_comments, " \t") };
}

pub fn tokenize(source: []const u8) LineIterator {
    return LineIterator{ .source_iter = sepatareLines(source) };
}

pub fn createFnTable(line_iter: *LineIterator, allocator: std.mem.Allocator) FunctionTableError!FunctionTable {
    var func_table = FunctionTable.init(allocator);

    while (line_iter.next()) |line| {
        var line_mut = line;
        const instr_name = line_mut.first() orelse continue;

        if (std.mem.eql(u8, instr_name, "FUNC")) {
            const func_name = line_mut.next() orelse return FunctionTableError.UnnamedFunction;

            if (func_table.get(func_name) != null)
                return FunctionTableError.AmbiguousName;

            const instr_iter = InstructionIterator.constructFuncBodyIterator(line_iter.*);
            func_table.putNoClobber(func_name, instr_iter) catch return FunctionTableError.HashMapError;
        }
    }

    return func_table;
}

pub fn destroyFnTable(func_table: FunctionTable) void {
    func_table.deinit();
}
