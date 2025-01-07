const std = @import("std");
const instruction = @import("../interpreter/instruction.zig");
const globals = @import("../interpreter/globals.zig");
const SourceObject = @import("../interpreter/SourceObject.zig");
const FunctionTable = SourceObject.FunctionTable;
const FunctionTableError = SourceObject.FunctionTableError;
const LangConfig = @import("../interpreter/LangConfig.zig");
const squashStrBlock = globals.squashStrBlock;

pub fn sepatareLines(source: []const u8) std.mem.SplitIterator(u8, .any) {
    return std.mem.splitAny(u8, source, "\r\n\r");
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
        var self_cpy = self;
        return self_cpy.next();
    }

    pub fn first(self: *ArgumentIterator) ?[]const u8 {
        self.line_iter.index = 0;
        return self.next();
    }

    pub fn peekInstrName(self: ArgumentIterator) ?[]const u8 {
        var self_cpy = self;
        return self_cpy.first();
    }
};

pub const InstructionIterator = struct {
    line_iter: LineIterator,
    is_func: bool = false,
    func_body: bool = false,
    code_block: bool = false,

    pub fn construct(line_iter: LineIterator) InstructionIterator {
        return InstructionIterator{ .line_iter = line_iter };
    }

    pub fn constructFuncBodyIterator(line_iter: LineIterator) InstructionIterator {
        return InstructionIterator{ .line_iter = line_iter, .is_func = true, .func_body = true };
    }

    pub fn continueCodeBlockIterator(self: *InstructionIterator) *InstructionIterator {
        self.code_block = true;
        return self;
    }

    pub fn continueInstructionIterator(self: *InstructionIterator) *InstructionIterator {
        self.code_block = false;
        return self;
    }

    pub fn next(self: *InstructionIterator) ?ArgumentIterator {
        return while (self.line_iter.next()) |arg_iter| {
            if (self.func_body and !self.is_func)
                break null;

            const instr_name = arg_iter.peekInstrName() orelse continue;

            if (self.code_block) {
                if (instruction.Instruction.fromString(instr_name)) |instr| {
                    switch (instr) {
                        .END, .ENDWHILE => break null,
                        else => {},
                    }
                }
            }

            if (!self.is_func) {
                if (std.mem.eql(u8, instr_name, "func")) {
                    self.is_func = true;
                    continue;
                }
            } else {
                if (std.mem.eql(u8, instr_name, "endfunc")) {
                    if (self.func_body)
                        break null;

                    self.is_func = false;
                }

                if (!self.func_body)
                    continue;
            }

            break arg_iter;
        } else null;
    }

    pub fn peek(self: InstructionIterator) ?ArgumentIterator {
        var self_cpy = self;
        return self_cpy.next();
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

pub fn readLangConfig(instr_iter: *InstructionIterator) LangConfig {
    var lang_config = LangConfig{};

    while (instr_iter.peek()) |arg_iter| : (_ = instr_iter.next()) {
        if (arg_iter.peekInstrName()) |instr_name| {
            if (instr_name[0] == '?') {
                var kv_pair = std.mem.splitScalar(u8, instr_name, '=');

                const key = blk: {
                    const q_key = kv_pair.first();
                    if (q_key.len <= 1)
                        continue;

                    break :blk q_key[1..];
                };

                const value = kv_pair.next() orelse continue;

                switch (squashStrBlock(key)) {
                    squashStrBlock("language"), squashStrBlock("lang") => lang_config.language = std.meta.stringToEnum(LangConfig.Language, value) orelse continue,
                    squashStrBlock("langver") => lang_config.version = value,
                    else => continue,
                }
            } else break;
        }
    }

    return lang_config;
}

pub fn createFnTable(line_iter: *LineIterator, allocator: std.mem.Allocator) FunctionTableError!FunctionTable {
    var func_table = FunctionTable.init(allocator);

    while (line_iter.next()) |line| {
        var line_mut = line;
        const instr_name = line_mut.first() orelse continue;

        if (std.mem.eql(u8, instr_name, "func")) {
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
