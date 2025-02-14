const std = @import("std");

const byte_parser = @import("../../../parser/byte_parser.zig");
const riff = @import("../riff.zig");
const SubchunkIterator = @import("./SubchunkIterator.zig");
const Subchunk = @import("./Subchunk.zig");
const ChunkError = riff.ChunkError;

const RiffChunk = @This();

pub const riff_format_s = 4;

pub const riff_chunk_size = riff.chunk_id_s + riff.chunk_size_s + riff_format_s;

pub const riff_chunk_id: [riff.chunk_id_s]u8 = "RIFF".*;

size: u32,
format: [riff_format_s]u8,
data: []const u8,
allocator: ?std.mem.Allocator = null,

pub fn subchunks(self: RiffChunk) SubchunkIterator {
    return SubchunkIterator{ .index = 0, .data = self.data };
}

pub fn construct(format: [riff_format_s]u8, data: []const u8) RiffChunk {
    return RiffChunk{ .size = @intCast(data.len + riff_format_s), .format = format, .data = data };
}

pub fn constructOwned(format: [riff_format_s]u8, chunkies: []const Subchunk, allocator: std.mem.Allocator) (std.mem.Allocator.Error || ChunkError)!RiffChunk {
    var size: u32 = 0;
    for (chunkies) |subchunk| {
        size += subchunk.size + Subchunk.size_margin;
    }

    const buffer = try allocator.alloc(u8, size);
    for (buffer) |*byte| {
        byte.* = '.';
    }

    var buf_stream = std.io.fixedBufferStream(buffer);
    const writer = buf_stream.writer();

    for (chunkies) |subchunk| {
        writer.writeAll(&subchunk.id) catch return ChunkError.InvalidSize;
        writer.writeInt(u32, subchunk.size, .little) catch return ChunkError.InvalidSize;
        writer.writeAll(subchunk.data) catch return ChunkError.InvalidSize;
    }

    return RiffChunk{ .size = size + riff_format_s, .format = format, .data = buffer, .allocator = allocator };
}

pub fn bytes(self: RiffChunk, allocator: std.mem.Allocator) (std.mem.Allocator.Error || ChunkError)![]const u8 {
    const buffer = try allocator.alloc(u8, riff_chunk_size + self.size);
    var buf_stream = std.io.fixedBufferStream(buffer);
    const writer = buf_stream.writer();

    writer.writeAll(&riff_chunk_id) catch return ChunkError.InvalidSize;
    writer.writeInt(u32, self.size, .little) catch return ChunkError.InvalidSize;
    writer.writeAll(&self.format) catch return ChunkError.InvalidSize;
    writer.writeAll(self.data) catch return ChunkError.InvalidSize;

    return buffer;
}

pub fn dispose(self: RiffChunk) void {
    if (self.allocator) |allocator| {
        allocator.free(self.data);
    }
}
