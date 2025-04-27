const std = @import("std");
const log = @import("lib/commandline/log.zig");

pub const IR_parser = @import("lib/parser/IR_parser.zig");
pub const WavFile = @import("lib/audio/wave/WavFile.zig");

test {
    std.testing.refAllDecls(@This());
}
