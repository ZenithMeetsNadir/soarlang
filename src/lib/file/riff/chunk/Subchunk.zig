const riff = @import("../riff.zig");
const RiffChunk = @import("./RiffChunk.zig");

pub const size_margin = riff.chunk_id_s + riff.chunk_size_s;

id: [riff.chunk_id_s]u8,
size: u32,
data: []const u8,
