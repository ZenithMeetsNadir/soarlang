const std = @import("std");
const fs = std.fs;

const file_ops = @import("file_ops.zig");
const WavFile = @import("../audio/wave/WavFile.zig");
const riff = @import("./riff/riff.zig");
const Subchunk = riff.Subchunk;
const RiffChunk = riff.RiffChunk;
const RiffIterator = riff.RiffIterator;

const MediaFile = @This();

pub const AudioFileError = error{
    InvalidExtension,
};

allocator: std.mem.Allocator,
path: []const u8,
data: []const u8,

/// passed data are cloned
pub fn construct(path: []const u8, data: []const u8, allocator: std.mem.Allocator) std.mem.Allocator.Error!MediaFile {
    const data_cpy = try allocator.dupe(u8, data);

    return MediaFile{ .allocator = allocator, .path = path, .data = data_cpy };
}

pub fn dispose(self: MediaFile) void {
    self.allocator.free(self.data);
}

pub fn open(path: []const u8, allocator: std.mem.Allocator) !MediaFile {
    var a_file = try construct(path, &[_]u8{}, allocator);
    errdefer a_file.dispose();

    try a_file.read(allocator);
    return a_file;
}

pub fn read(self: *MediaFile, allocator: std.mem.Allocator) (fs.File.OpenError || std.mem.Allocator.Error || fs.File.GetSeekPosError || fs.File.ReadError)!void {
    self.data = try file_ops.readFile(self.path, allocator);
}

pub fn save(self: MediaFile) (std.fs.File.OpenError || std.fs.File.WriteError)!void {
    try file_ops.saveFile(self.path, self.data);
}

pub fn fromAnyAudio(audio: anytype, allocator: std.mem.Allocator) !MediaFile {
    switch (@TypeOf(audio)) {
        WavFile => {
            const wav_audio = @as(WavFile, audio);

            const data_chunk = Subchunk{ .id = "data".*, .size = @intCast(wav_audio.data.len), .data = wav_audio.data };
            const riff_chunk = try RiffChunk.constructOwned(WavFile.wav_riff_format, &[_]Subchunk{ wav_audio.fmt.toSubchunk(), data_chunk }, allocator);
            defer riff_chunk.dispose();

            const bytes = try riff_chunk.bytes(allocator);

            // initialize 'MediaFile' by hand to avoid unnecessary data cloning
            return MediaFile{ .path = wav_audio.path, .data = bytes, .allocator = allocator };
        },
        else => @compileError("Unsupported audio type"),
    }
}

pub fn riffIterator(self: MediaFile) RiffIterator {
    return RiffIterator{ .index = 0, .data = self.data };
}
