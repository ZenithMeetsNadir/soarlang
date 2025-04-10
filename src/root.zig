const std = @import("std");

pub const IR_parser = @import("lib/parser/IR_parser.zig");
pub const WavFile = @import("lib/audio/wave/WavFile.zig");

test {
    std.testing.refAllDecls(@This());
}
