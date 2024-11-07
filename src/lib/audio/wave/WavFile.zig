const std = @import("std");

const WavHeader = @import("WavHeader.zig");
const AudioFile = @import("../../file/AudioFile.zig");
const WavFile = @This();

path: []const u8,
header: *WavHeader,
data: []const u8,

pub fn create(path: []const u8, header: WavHeader, data: []const u8, allocator: std.mem.Allocator) std.mem.Allocator.Error!*WavFile {
    const file: *WavFile = try allocator.create(WavFile);
    errdefer allocator.destroy(file);

    const path_copy = try allocator.alloc(u8, path.len);
    errdefer allocator.free(path_copy);
    std.mem.copyForwards(u8, path_copy, path);
    file.path = path_copy;

    file.header = try allocator.create(WavHeader);
    errdefer allocator.destroy(file.header);
    std.mem.copyForwards(u8, &file.header.header_bytes, &header.header_bytes);

    const data_copy = try allocator.alloc(u8, data.len);
    std.mem.copyForwards(u8, data_copy, data);
    file.data = data_copy;

    return file;
}

pub fn dispose(self: *WavFile, create_allocator: std.mem.Allocator) void {
    create_allocator.free(self.path);
    create_allocator.destroy(self.header);
    create_allocator.free(self.data);
}

pub fn @"export"(self: *const WavFile, allocator: std.mem.Allocator) !void {
    self.header.setSubchunk2Size(@intCast(self.data.len));

    const a_file: *AudioFile = (try AudioFile.fromAnyAudio(self.*, allocator)).?;
    defer allocator.destroy(a_file);
    defer a_file.dispose(allocator);

    try a_file.save();
}

pub fn fromAudioFile(a_file: *const AudioFile, allocator: std.mem.Allocator) (std.mem.Allocator.Error || AudioFile.AudioFileError)!*WavFile {
    if (!std.mem.eql(u8, std.fs.path.extension(a_file.path), ".wav"))
        return AudioFile.AudioFileError.InvalidExtension;

    const header_bytes = a_file.data[0..WavHeader.data_offset];
    const header = WavHeader{ .header_bytes = header_bytes.* };
    const data = a_file.data[WavHeader.data_offset..];

    const file = try create(a_file.path, header, data, allocator);

    return file;
}
