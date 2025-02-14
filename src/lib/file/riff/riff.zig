const std = @import("std");

const MediaFile = @import("../MediaFile.zig");

pub const SubchunkIterator = @import("chunk/SubchunkIterator.zig");
pub const Subchunk = @import("chunk/Subchunk.zig");
pub const RiffIterator = @import("chunk/RiffIterator.zig");
pub const RiffChunk = @import("chunk/RiffChunk.zig");

pub const chunk_id_s = 4;
pub const chunk_size_s = 4;

pub const RiffError = error{
    NotAriff,
    InvalidFormat,
};

pub const ChunkError = error{
    InvalidSize,
};

underlying_file: MediaFile,
