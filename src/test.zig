const std = @import("std");
const expect = std.testing.expect;

const WavFile = @import("lib/audio/wave/WavFile.zig");
const WavHeader = @import("lib/audio/wave/WavHeader.zig");
const AudioFile = @import("lib/file/AudioFile.zig");

test "audio file r/w" {
    const allocator = std.heap.page_allocator;

    const path = "test.wav";
    const header = WavHeader.construct(null, null, null);
    const data = "loads of data";

    const file = try WavFile.create(path, header, data, allocator);
    defer allocator.destroy(file);
    defer file.dispose(allocator);

    try file.@"export"(allocator);

    const a_file = try AudioFile.open("test.wav", allocator);
    defer allocator.destroy(a_file);
    defer a_file.dispose(allocator);

    const cr_file = try WavFile.fromAudioFile(a_file, allocator);
    defer allocator.destroy(cr_file);
    defer cr_file.dispose(allocator);

    try expect(std.mem.eql(u8, cr_file.data, "loads of data"));
}
