const std = @import("std");
const fs = std.fs;

const file = @import("file.zig");
const wave = @import("../audio/wave/wave.zig");

const AudioFile = @This();

pub const Error = error{
    InvalidExtension,
};

path: []const u8,
data: []const u8,

pub fn create(path: []const u8, data: []const u8, allocator: std.mem.Allocator) std.mem.Allocator.Error!*AudioFile {
    const cr_file: *AudioFile = try allocator.create(AudioFile);
    errdefer allocator.destroy(cr_file);

    const path_copy = try allocator.alloc(u8, path.len);
    errdefer allocator.free(path_copy);
    std.mem.copyForwards(u8, path_copy, path);
    cr_file.path = path_copy;

    const data_copy = try allocator.alloc(u8, data.len);
    std.mem.copyForwards(u8, data_copy, data);
    cr_file.data = data_copy;

    return cr_file;
}

pub fn dispose(self: AudioFile, create_allocator: std.mem.Allocator) void {
    create_allocator.free(self.path);
    create_allocator.free(self.data);
}

pub fn open(path: []const u8, allocator: std.mem.Allocator) !*AudioFile {
    const a_file = try create(path, .{}, allocator);
    errdefer allocator.destroy(a_file);

    try a_file.fetch(allocator);

    return a_file;
}

pub fn fetch(self: *AudioFile, allocator: std.mem.Allocator) (fs.File.OpenError || std.mem.Allocator.Error || fs.File.GetSeekPosError || fs.File.ReadError)!void {
    self.data = try file.readFile(self.path, allocator);
}

pub fn save(self: AudioFile) (std.fs.File.OpenError || std.fs.File.WriteError)!void {
    try file.saveFile(self.path, self.data);
}

pub fn fromAnyAudio(audio: anytype, allocator: std.mem.Allocator) std.mem.Allocator.Error!?*AudioFile {
    switch (@TypeOf(audio)) {
        wave.WavFile => {
            const wav_audio = @as(wave.WavFile, audio);
            const data = try std.mem.concat(allocator, u8, &[_][]const u8{ &wav_audio.header.header_bytes, wav_audio.data });

            const a_file: *AudioFile = try create(wav_audio.path, data, allocator);

            return a_file;
        },
        else => return null,
    }
}
