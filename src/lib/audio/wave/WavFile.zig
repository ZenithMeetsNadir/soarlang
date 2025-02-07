const std = @import("std");

const WavHeader = @import("WavHeader.zig");
const AudioFile = @import("../../file/AudioFile.zig");
const WavFile = @This();

allocator: std.mem.Allocator,
path: []const u8,
header: *WavHeader,
data: []const u8,

pub fn construct(path: []const u8, header: WavHeader, data: []const u8, allocator: std.mem.Allocator) std.mem.Allocator.Error!WavFile {
    const path_cpy = try allocator.dupe(u8, path);
    errdefer allocator.free(path_cpy);

    const header_cpy = try allocator.create(WavHeader);
    errdefer allocator.destroy(header_cpy);
    std.mem.copyForwards(u8, &header_cpy.header_bytes, &header.header_bytes);

    const data_cpy = try allocator.dupe(u8, data);

    return WavFile{ .allocator = allocator, .path = path_cpy, .header = header_cpy, .data = data_cpy };
}

pub fn dispose(self: WavFile) void {
    self.allocator.free(self.path);
    self.allocator.destroy(self.header);
    self.allocator.free(self.data);
}

pub fn @"export"(self: *const WavFile, allocator: std.mem.Allocator) !void {
    self.header.setSubchunk2Size(@intCast(self.data.len));

    const a_file = try AudioFile.fromAnyAudio(self.*, allocator);
    defer a_file.dispose();

    try a_file.save();
}

pub fn fromAudioFile(a_file: *const AudioFile, allocator: std.mem.Allocator) (std.mem.Allocator.Error || AudioFile.AudioFileError)!WavFile {
    if (!std.mem.eql(u8, std.fs.path.extension(a_file.path), ".wav"))
        return AudioFile.AudioFileError.InvalidExtension;

    const header_bytes = a_file.data[0..WavHeader.data_offset];
    const header = WavHeader{ .header_bytes = header_bytes.* };
    const data = a_file.data[WavHeader.data_offset..];

    const file = try construct(a_file.path, header, data, allocator);

    return file;
}
