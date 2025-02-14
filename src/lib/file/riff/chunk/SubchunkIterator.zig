const std = @import("std");

const Subchunk = @import("./Subchunk.zig");
const riff = @import("../riff.zig");
const RiffChunk = @import("./RiffChunk.zig");
const byte_parser = @import("../../../parser/byte_parser.zig");

const SubchunkIterator = @This();

index: usize = 0,
data: []const u8,

pub fn next(self: *SubchunkIterator) ?Subchunk {
    if (self.index >= self.data.len)
        return null;

    const id = self.data[self.index .. self.index + riff.chunk_id_s];
    self.index += riff.chunk_id_s;

    const size = byte_parser.assemb(u32, self.data[self.index .. self.index + riff.chunk_size_s], .little);
    self.index += riff.chunk_size_s;

    const end = self.index + size;
    if (end > self.data.len)
        return null;

    const data = self.data[self.index..end];
    self.index += size;

    return Subchunk{ .id = id[0..RiffChunk.riff_format_s].*, .size = size, .data = data };
}

pub fn chunkByIdContinue(self: *SubchunkIterator, id: []const u8) ?Subchunk {
    return while (self.next()) |subchunk| {
        if (std.mem.eql(u8, &subchunk.id, id))
            break subchunk;
    } else null;
}

pub fn chunkById(self: *SubchunkIterator, id: []const u8) ?Subchunk {
    self.index = 0;
    return self.chunkByIdContinue(id);
}
