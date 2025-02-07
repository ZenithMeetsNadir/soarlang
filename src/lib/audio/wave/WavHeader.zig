const std = @import("std");
const assert = std.debug.assert;

const byte_parser = @import("../../parser/byte_parser.zig");
const WavHeader = @This();

pub const chunk_id_size = 4;
pub const chunk_size_size = 4;
pub const format_size = 4;

pub const subchunk1_id_size = 4;
pub const subchunk1_size_size = 4;
pub const audio_format_size = 2;
pub const num_channels_size = 2;
pub const sample_rate_size = 4;
pub const byte_rate_size = 4;
pub const block_align_size = 2;
pub const bits_per_sample_size = 2;

pub const subchunk2_id_size = 4;
pub const subchunk2_size_size = 4;

pub const chunk_id: [chunk_id_size]u8 = "RIFF".*;
pub const format: [format_size]u8 = "WAVE".*;

pub const subchunk1_id: [subchunk1_id_size]u8 = "fmt ".*;
pub const subchunk1_size: [subchunk1_size_size]u8 = byte_parser.distr(u32, subchunk1_size_value, .little);
pub const audio_format: [audio_format_size]u8 = byte_parser.distr(u16, 1, .little);

pub const subchunk2_id: [subchunk2_id_size]u8 = "data".*;

pub const subchunk1_size_value = audio_format_size + num_channels_size + sample_rate_size + byte_rate_size + block_align_size + bits_per_sample_size;
pub const chunk_data_offset = format_size + subchunk1_id_size + subchunk1_size_size + audio_format_size + num_channels_size + sample_rate_size + byte_rate_size + block_align_size + bits_per_sample_size + subchunk2_id_size + subchunk2_size_size;

pub const chunk_id_offset = 0;
pub const chunk_size_offset = chunk_id_offset + chunk_id_size;
pub const format_offset = chunk_size_offset + chunk_size_size;
pub const subchunk1_id_offset = format_size + format_offset;
pub const subchunk1_size_offset = subchunk1_id_offset + subchunk1_id_size;
pub const audio_format_offset = subchunk1_size_offset + subchunk1_size_size;
pub const num_channels_offset = audio_format_offset + audio_format_size;
pub const sample_rate_offset = num_channels_offset + num_channels_size;
pub const byte_rate_offset = sample_rate_offset + sample_rate_size;
pub const block_align_offset = byte_rate_offset + byte_rate_size;
pub const bits_per_sample_offset = block_align_offset + block_align_size;
pub const subchunk2_id_offset = bits_per_sample_offset + bits_per_sample_size;
pub const subchunk2_size_offset = subchunk2_id_offset + subchunk2_id_size;
pub const data_offset = blk: {
    const d_offset = subchunk2_size_offset + subchunk2_size_size;
    assert(d_offset == 44);
    break :blk d_offset;
};

pub const num_channels_default = 1;
pub const sample_rate_default = 44100;
pub const bits_per_sample_default = 16;

header_bytes: [data_offset]u8 = undefined,

pub fn construct(num_channels: ?u16, sample_rate: ?u32, bits_per_sample: ?u16) WavHeader {
    var header = WavHeader{};

    header.write(&chunk_id, chunk_id_offset);
    header.write(&format, format_offset);

    header.write(&subchunk1_id, subchunk1_id_offset);
    header.write(&subchunk1_size, subchunk1_size_offset);
    header.write(&audio_format, audio_format_offset);

    header.write(&subchunk2_id, subchunk2_id_offset);

    header.setNumChannels(num_channels orelse num_channels_default);
    header.setSampleRate(sample_rate orelse sample_rate_default);
    header.setBitsPerSample(bits_per_sample orelse bits_per_sample_default);

    return header;
}

pub fn write(self: *WavHeader, data: []const u8, start_index: usize) void {
    for (data, 0..) |byte, i| {
        const index = start_index + i;

        if (index < self.header_bytes.len)
            self.header_bytes[index] = byte;
    }
}

pub fn getChunkSize(self: WavHeader) u32 {
    return byte_parser.assemb(u32, self.header_bytes[4 .. 4 + chunk_size_size], .little);
}

pub fn updateChunkSize(self: *WavHeader) void {
    self.write(&byte_parser.distr(u32, self.getSubchunk2Size() + chunk_data_offset, .little), chunk_size_offset);
}

pub fn getNumChannels(self: WavHeader) u16 {
    return byte_parser.assemb(u16, self.header_bytes[num_channels_offset .. num_channels_offset + num_channels_size], .little);
}

pub fn setNumChannels(self: *WavHeader, num_channels: u16) void {
    self.write(&byte_parser.distr(u16, num_channels, .little), num_channels_offset);
    self.updateByteRate();
    self.updateBlockAlign();
}

pub fn getSampleRate(self: WavHeader) u32 {
    return byte_parser.assemb(u32, self.header_bytes[sample_rate_offset .. sample_rate_offset + sample_rate_size], .little);
}

pub fn setSampleRate(self: *WavHeader, sample_rate: u32) void {
    self.write(&byte_parser.distr(u32, sample_rate, .little), sample_rate_offset);
    self.updateByteRate();
}

pub fn getByteRate(self: WavHeader) u32 {
    return byte_parser.assemb(u32, self.header_bytes[byte_rate_offset .. byte_rate_offset + byte_rate_size], .little);
}

pub fn updateByteRate(self: *WavHeader) void {
    const byte_rate: u32 = self.getSampleRate() *| self.getBitsPerSample() * self.getNumChannels() / 8;
    self.write(&byte_parser.distr(u32, byte_rate, .little), byte_rate_offset);
}

pub fn getBlockAlign(self: WavHeader) u16 {
    return byte_parser.assemb(u16, self.header_bytes[block_align_offset .. block_align_offset + block_align_size], .little);
}

pub fn updateBlockAlign(self: *WavHeader) void {
    const block_align: u16 = self.getBitsPerSample() * self.getNumChannels() / 8;
    self.write(&byte_parser.distr(u16, block_align, .little), block_align_offset);
}

pub fn getBitsPerSample(self: WavHeader) u16 {
    return byte_parser.assemb(u16, self.header_bytes[bits_per_sample_offset .. bits_per_sample_offset + bits_per_sample_size], .little);
}

pub fn setBitsPerSample(self: *WavHeader, bits_per_sample: u16) void {
    self.write(&byte_parser.distr(u16, bits_per_sample, .little), bits_per_sample_offset);
    self.updateByteRate();
    self.updateBlockAlign();
}

pub fn getSubchunk2Size(self: WavHeader) u32 {
    return byte_parser.assemb(u32, self.header_bytes[subchunk2_size_offset .. subchunk2_size_offset + subchunk2_size_size], .little);
}

pub fn setSubchunk2Size(self: *WavHeader, subchunk2_size: u32) void {
    self.write(&byte_parser.distr(u32, subchunk2_size, .little), subchunk2_size_offset);
    self.updateChunkSize();
}
