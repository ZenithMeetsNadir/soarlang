const std = @import("std");
const fs = std.fs;
const assert = std.debug.assert;

pub fn readFile(path: []const u8, allocator: std.mem.Allocator) (fs.File.OpenError || std.mem.Allocator.Error || fs.File.GetSeekPosError || fs.File.ReadError)![]const u8 {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    errdefer allocator.free(buffer);

    const bytes_read = try file.readAll(buffer);
    assert(file_size == bytes_read);

    return buffer;
}

pub fn saveFile(path: []const u8, data: []const u8) (std.fs.File.OpenError || std.fs.File.WriteError)!void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(data);
}
