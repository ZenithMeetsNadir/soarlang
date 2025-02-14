const std = @import("std");
const riff = @import("../riff.zig");
const RiffChunk = @import("./RiffChunk.zig");
const byte_parser = @import("../../../parser/byte_parser.zig");

const RiffIterator = @This();

index: ?usize = null,
data: []const u8,

pub fn riffChunk(self: *RiffIterator) riff.RiffError!RiffChunk {
    if (self.data.len < RiffChunk.riff_chunk_size)
        return riff.RiffError.InvalidFormat;

    self.index = 0;
    const chunk_id = self.data[self.index.? .. self.index.? + riff.chunk_id_s];
    if (!std.mem.eql(u8, chunk_id, &RiffChunk.riff_chunk_id))
        return riff.RiffError.NotAriff;

    self.index.? += riff.chunk_id_s;

    const size = byte_parser.assemb(u32, self.data[self.index.? .. self.index.? + riff.chunk_size_s], .little);
    self.index.? += riff.chunk_size_s;

    const format = self.data[self.index.? .. self.index.? + RiffChunk.riff_format_s];
    self.index.? += RiffChunk.riff_format_s;

    const end = self.index.? + size - RiffChunk.riff_format_s;
    if (end > self.data.len)
        return riff.RiffError.InvalidFormat;

    const data = self.data[self.index.?..end];
    self.index.? += size;

    return RiffChunk.construct(format[0..RiffChunk.riff_format_s].*, data);
}
