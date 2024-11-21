const std = @import("std");

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
};

pub const InstructionIterator = struct {
    source_iter: std.mem.SplitIterator(u8, .any),

    pub fn next(self: *InstructionIterator) ?ArgumentIterator {
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

pub fn tokenize(source: []const u8) InstructionIterator {
    return InstructionIterator{ .source_iter = sepatareLines(source) };
}
