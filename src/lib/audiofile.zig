const std = @import("std");
const wave = @import("wave.zig");

pub const AudioFile = struct {
    path: []const u8,
    data: []const u8,

    pub fn save(self: *const AudioFile) (std.fs.File.OpenError || std.fs.File.WriteError)!void {
        const file = try std.fs.cwd().createFile(self.path, .{});
        defer file.close();

        try file.writeAll(self.data);
    }

    pub fn fromAnyAudio(audio: anytype, allocator: std.mem.Allocator) std.mem.Allocator.Error!?AudioFile {
        switch (@TypeOf(audio)) {
            wave.WavFile => {
                const data = try std.mem.concat(allocator, u8, &[_][]const u8{ &audio.header.header_bytes, audio.data });
                return AudioFile{ .path = audio.path, .data = data };
            },
            else => return null,
        }
    }
};
