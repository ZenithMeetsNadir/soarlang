const std = @import("std");
const instruction = @import("../interpreter/instruction.zig");
const global = @import("../interpreter/global.zig");
const SourceObject = @import("../interpreter/SourceObject.zig");
const FunctionTable = SourceObject.FunctionTable;
const FunctionTableError = SourceObject.FunctionTableError;
const LangConfig = @import("../interpreter/LangConfig.zig");
const byte_parser = @import("./byte_parser.zig");
const squashStrBlock = byte_parser.squashStrBlock;

pub const config_prefix: u8 = '?';

pub fn sepatareLines(source: []const u8) std.mem.SplitIterator(u8, .any) {
    return std.mem.splitAny(u8, source, "\r\n");
}

pub const ArgumentIterator = struct {
    line_iter: std.mem.SplitIterator(u8, .any),
    is_quoted_str: bool = false,

    fn isValid(self: *ArgumentIterator, word: []const u8) bool {
        if (word.len > 0 and word[0] == '"' and !self.is_quoted_str) {
            self.is_quoted_str = true;
            return false;
        }

        return word.len > 0;
    }

    pub fn next(self: *ArgumentIterator) ?[]const u8 {
        var start_quote = self.line_iter.index orelse return null;
        return ret_wh: while (self.line_iter.next()) |word| : (start_quote = self.line_iter.index orelse return null) {
            if (self.isValid(word)) {
                break :ret_wh word;
            } else if (self.is_quoted_str) {
                var end_quote: usize = start_quote;
                while (blk: {
                    end_quote = std.mem.indexOfScalarPos(u8, self.line_iter.buffer, end_quote + 1, '"') orelse break :ret_wh null;
                    break :blk self.line_iter.buffer[end_quote - 1] == '\\';
                }) {}

                self.line_iter.index = if (self.line_iter.buffer.len > end_quote + 2) end_quote + 2 else null;
                self.is_quoted_str = false;
                break :ret_wh self.line_iter.buffer[start_quote + 1 .. end_quote];
            }
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

pub fn purifyStrLiteral(source: []const u8, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    try std.mem.replaceOwned(u8, allocator, source, "\\\"", "\"");
}

pub fn acknowledgeSymbPrefix(str: []const u8, prefix: u8) ?[]const u8 {
    if (str.len <= 1 or str[0] != prefix)
        return null;

    return str[1..];
}

pub fn readLangConfig(instr_iter: *InstructionIterator) LangConfig {
    var lang_config = LangConfig{};

    while (instr_iter.peek()) |arg_iter| : (_ = instr_iter.next()) {
        if (arg_iter.peekInstrName()) |q_config| {
            if (acknowledgeSymbPrefix(q_config, config_prefix)) |config| {
                var kv_pair = std.mem.splitScalar(u8, config, '=');
                const key = kv_pair.first();
                const value = kv_pair.next() orelse continue;

                switch (squashStrBlock(key)) {
                    squashStrBlock("language"), squashStrBlock("lang") => lang_config.language = std.meta.stringToEnum(LangConfig.Language, value) orelse continue,
                    squashStrBlock("langver") => lang_config.lang_version = value,
                    squashStrBlock("exectype") => lang_config.exec_type = std.meta.stringToEnum(LangConfig.ExecType, value) orelse continue,
                    else => continue,
                }
            }

            if (q_config[0] != config_prefix)
                break;
        }
    }

    return lang_config;
}
