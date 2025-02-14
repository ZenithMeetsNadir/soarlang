const std = @import("std");
const expect = std.testing.expect;

const WavFile = @import("lib/audio/wave/WavFile.zig");
const Fmt_Chunk = @import("lib/audio/wave/Fmt_Chunk.zig");
const MediaFile = @import("lib/file/MediaFile.zig");

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
