const std = @import("std");

const MediaFile = @import("../../file/MediaFile.zig");
const Fmt_Chunk = @import("./Fmt_Chunk.zig");
const riff = @import("../../file/riff/riff.zig");

const WavFile = @This();

const expect = std.testing.expect;

pub const wav_riff_format: [riff.RiffChunk.riff_format_s]u8 = "WAVE".*;

allocator: std.mem.Allocator,
path: []const u8,
fmt: Fmt_Chunk,
data: []const u8,

/// data are cloned
pub fn construct(path: []const u8, fmt: Fmt_Chunk, data: []const u8, allocator: std.mem.Allocator) std.mem.Allocator.Error!WavFile {
    const data_cpy = try allocator.dupe(u8, data);

    return WavFile{ .allocator = allocator, .path = path, .fmt = fmt, .data = data_cpy };
}

pub fn dispose(self: WavFile) void {
    self.allocator.free(self.data);
}

pub fn fromMediaFile(m_file: MediaFile, allocator: std.mem.Allocator) (std.mem.Allocator.Error || riff.RiffError || MediaFile.AudioFileError)!WavFile {
    if (!std.mem.eql(u8, std.fs.path.extension(m_file.path), ".wav"))
        return MediaFile.AudioFileError.InvalidExtension;

    var riff_iter = m_file.riffIterator();
    const riff_chunk = try riff_iter.riffChunk();
    var subchunk_iter = riff_chunk.subchunks();
    const fmt__chunk = subchunk_iter.chunkByIdContinue("fmt ");
    if (fmt__chunk == null)
        return riff.RiffError.InvalidFormat;

    const fmt = Fmt_Chunk.fromSubchunk(fmt__chunk.?);

    const data_chunk = subchunk_iter.chunkByIdContinue("data");
    if (data_chunk == null)
        return riff.RiffError.InvalidFormat;

    const file = try construct(m_file.path, fmt, data_chunk.?.data, allocator);

    return file;
}

test "audio file r/w" {
    const allocator = std.testing.allocator;

    const path = "test.wav";
    const fmt = Fmt_Chunk.construct(null, null, null);
    const data = "loads of data";

    const w_file = try WavFile.construct(path, fmt, data, allocator);
    defer w_file.dispose();

    try expect(std.mem.eql(u8, w_file.data, data));

    const m_file = try MediaFile.fromAnyAudio(w_file, allocator);
    defer m_file.dispose();

    try m_file.save();

    const a_file = try MediaFile.open("test.wav", allocator);
    defer a_file.dispose();

    const cr_file = try WavFile.fromMediaFile(a_file, allocator);
    defer cr_file.dispose();

    try expect(std.mem.eql(u8, cr_file.data, data));
}

test "read test track metadata" {
    const allocator = std.testing.allocator;

    const m_file = try MediaFile.open("C:\\Users\\marti\\testing data\\wav\\písek.wav", allocator);
    defer m_file.dispose();

    const w_file = try WavFile.fromMediaFile(m_file, allocator);
    defer w_file.dispose();
}
