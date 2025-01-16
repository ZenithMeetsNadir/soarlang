const std = @import("std");
const fs = std.fs;
const assert = std.debug.assert;

pub const ParentDirError = error{
    PathNotFound,
};

pub fn readFileFromDir(dir: fs.Dir, path: []const u8, allocator: std.mem.Allocator) (fs.File.OpenError || std.mem.Allocator.Error || fs.File.GetSeekPosError || fs.File.ReadError)![]const u8 {
    const file = try dir.openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    errdefer allocator.free(buffer);

    const bytes_read = try file.readAll(buffer);
    assert(file_size == bytes_read);

    return buffer;
}

pub fn readFile(path: []const u8, allocator: std.mem.Allocator) (fs.File.OpenError || std.mem.Allocator.Error || fs.File.GetSeekPosError || fs.File.ReadError)![]const u8 {
    return try readFileFromDir(fs.cwd(), path, allocator);
}

pub fn getParentDirPath(path: []const u8) ParentDirError![]const u8 {
    var path_iter = fs.path.ComponentIterator(.windows, u8).init(path) catch return ParentDirError.PathNotFound;

    while (path_iter.next()) |_| {}

    const parent_path = path_iter.previous() orelse return ParentDirError.PathNotFound;
    return parent_path.path;
}

pub fn saveFile(path: []const u8, data: []const u8) (std.fs.File.OpenError || std.fs.File.WriteError)!void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(data);
}
