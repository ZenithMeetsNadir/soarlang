const std = @import("std");

const riff = @import("../../file/riff/riff.zig");
const RiffChunk = @import("../../file/riff/chunk/RiffChunk.zig");
const Subchunk = @import("../../file/riff/chunk/Subchunk.zig");
const byte_parser = @import("../../parser/byte_parser.zig");

const Fmt_Chunk = @This();

pub const audio_format_size = 2;
pub const num_channels_size = 2;
pub const sample_rate_size = 4;
pub const byte_rate_size = 4;
pub const block_align_size = 2;
pub const bits_per_sample_size = 2;

pub const fmt__chunk_id: [riff.chunk_id_s]u8 = "fmt ".*;
pub const fmt__chunk_size = audio_format_size + num_channels_size + sample_rate_size + byte_rate_size + block_align_size + bits_per_sample_size;

pub const audio_format_offset = 0;
pub const num_channels_offset = audio_format_offset + audio_format_size;
pub const sample_rate_offset = num_channels_offset + num_channels_size;
pub const byte_rate_offset = sample_rate_offset + sample_rate_size;
pub const block_align_offset = byte_rate_offset + byte_rate_size;
pub const bits_per_sample_offset = block_align_offset + block_align_size;

pub const audio_format: [audio_format_size]u8 = byte_parser.distr(u16, 1, .little);

pub const num_channels_default = 1;
pub const sample_rate_default = 44100;
pub const bits_per_sample_default = 16;

fmt__data: [fmt__chunk_size]u8 = undefined,

pub fn construct(num_channels: ?u16, sample_rate: ?u32, bits_per_sample: ?u16) Fmt_Chunk {
    var fmt = Fmt_Chunk{};

    fmt.write(&audio_format, audio_format_offset);

    fmt.setNumChannels(num_channels orelse num_channels_default);
    fmt.setSampleRate(sample_rate orelse sample_rate_default);
    fmt.setBitsPerSample(bits_per_sample orelse bits_per_sample_default);

    return fmt;
}

pub fn fromSubchunk(fmt__chunk: Subchunk) Fmt_Chunk {
    return Fmt_Chunk{ .fmt__data = fmt__chunk.data[0..fmt__chunk_size].* };
}

pub fn toSubchunk(self: Fmt_Chunk) Subchunk {
    return Subchunk{ .id = fmt__chunk_id, .size = fmt__chunk_size, .data = &self.fmt__data };
}

pub fn write(self: *Fmt_Chunk, data: []const u8, start_index: usize) void {
    const end = start_index + data.len;
    if (end <= self.fmt__data.len)
        std.mem.copyForwards(u8, self.fmt__data[start_index..end], data);
}

pub fn getNumChannels(self: Fmt_Chunk) u16 {
    return byte_parser.assemb(u16, self.fmt__data[num_channels_offset .. num_channels_offset + num_channels_size], .little);
}

pub fn setNumChannels(self: *Fmt_Chunk, num_channels: u16) void {
    self.write(&byte_parser.distr(u16, num_channels, .little), num_channels_offset);
    self.updateByteRate();
    self.updateBlockAlign();
}

pub fn getSampleRate(self: Fmt_Chunk) u32 {
    return byte_parser.assemb(u32, self.fmt__data[sample_rate_offset .. sample_rate_offset + sample_rate_size], .little);
}

pub fn setSampleRate(self: *Fmt_Chunk, sample_rate: u32) void {
    self.write(&byte_parser.distr(u32, sample_rate, .little), sample_rate_offset);
    self.updateByteRate();
}

pub fn getByteRate(self: Fmt_Chunk) u32 {
    return byte_parser.assemb(u32, self.fmt__data[byte_rate_offset .. byte_rate_offset + byte_rate_size], .little);
}

pub fn updateByteRate(self: *Fmt_Chunk) void {
    const byte_rate: u32 = self.getSampleRate() *| self.getBitsPerSample() * self.getNumChannels() / 8;
    self.write(&byte_parser.distr(u32, byte_rate, .little), byte_rate_offset);
}

pub fn getBlockAlign(self: Fmt_Chunk) u16 {
    return byte_parser.assemb(u16, self.fmt__data[block_align_offset .. block_align_offset + block_align_size], .little);
}

pub fn updateBlockAlign(self: *Fmt_Chunk) void {
    const block_align: u16 = self.getBitsPerSample() * self.getNumChannels() / 8;
    self.write(&byte_parser.distr(u16, block_align, .little), block_align_offset);
}

pub fn getBitsPerSample(self: Fmt_Chunk) u16 {
    return byte_parser.assemb(u16, self.fmt__data[bits_per_sample_offset .. bits_per_sample_offset + bits_per_sample_size], .little);
}

pub fn setBitsPerSample(self: *Fmt_Chunk, bits_per_sample: u16) void {
    self.write(&byte_parser.distr(u16, bits_per_sample, .little), bits_per_sample_offset);
    self.updateByteRate();
    self.updateBlockAlign();
}
