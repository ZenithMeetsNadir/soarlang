const std = @import("std");
const expect = std.testing.expect;

const WavFile = @import("lib/audio/wave/WavFile.zig");
const WavHeader = @import("lib/audio/wave/WavHeader.zig");
const AudioFile = @import("lib/file/AudioFile.zig");

test "audio file r/w" {
    const allocator = std.testing.allocator;

    const path = "test.wav";
    const header = WavHeader.construct(null, null, null);
    const data = "loads of data";

    const file = try WavFile.construct(path, header, data, allocator);
    defer file.dispose();

    try file.@"export"(allocator);

    const a_file = try AudioFile.open("test.wav", allocator);
    defer a_file.dispose();

    const cr_file = try WavFile.fromAudioFile(&a_file, allocator);
    defer cr_file.dispose();

    try expect(std.mem.eql(u8, cr_file.data, "loads of data"));
}
