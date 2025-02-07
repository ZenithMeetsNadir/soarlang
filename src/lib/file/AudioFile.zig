const std = @import("std");
const fs = std.fs;

const file_ops = @import("file_ops.zig");
const WavFile = @import("../audio/wave/WavFile.zig");
const AudioFile = @This();

pub const AudioFileError = error{
    InvalidExtension,
};

allocator: std.mem.Allocator,
path: []const u8,
data: []const u8,

pub fn construct(path: []const u8, data: []const u8, allocator: std.mem.Allocator) std.mem.Allocator.Error!AudioFile {
    const path_cpy = try allocator.dupe(u8, path);
    errdefer allocator.free(path_cpy);

    const data_cpy = try allocator.dupe(u8, data);

    return AudioFile{ .allocator = allocator, .path = path_cpy, .data = data_cpy };
}

pub fn dispose(self: AudioFile) void {
    self.allocator.free(self.path);
    self.allocator.free(self.data);
}

pub fn open(path: []const u8, allocator: std.mem.Allocator) !AudioFile {
    var a_file = try construct(path, &[_]u8{}, allocator);
    errdefer a_file.dispose();

    try a_file.read(allocator);
    return a_file;
}

pub fn read(self: *AudioFile, allocator: std.mem.Allocator) (fs.File.OpenError || std.mem.Allocator.Error || fs.File.GetSeekPosError || fs.File.ReadError)!void {
    self.data = try file_ops.readFile(self.path, allocator);
}

pub fn save(self: AudioFile) (std.fs.File.OpenError || std.fs.File.WriteError)!void {
    try file_ops.saveFile(self.path, self.data);
}

pub fn fromAnyAudio(audio: anytype, allocator: std.mem.Allocator) std.mem.Allocator.Error!AudioFile {
    switch (@TypeOf(audio)) {
        WavFile => {
            const wav_audio = @as(WavFile, audio);
            const data = try std.mem.concat(allocator, u8, &[_][]const u8{ &wav_audio.header.header_bytes, wav_audio.data });
            defer allocator.free(data);

            const a_file = try construct(wav_audio.path, data, allocator);

            return a_file;
        },
        else => @compileError("Unsupported audio type"),
    }
}
