const std = @import("std");

const RiffFile = @This();

pub const chunk_id_s = 4;
pub const chunk_size_s = 4;
pub const format_s = 4;

pub const chunk_id: [chunk_id_s]u8 = "RIFF".*;

pub const ChunkIterator = struct {
    pub const Chunk = struct {
        id: [chunk_id_s]u8,
        size: u32,
        data: []const u8,
    };

    pos: usize,
    cur_size: usize,
    data: []const u8,
};
