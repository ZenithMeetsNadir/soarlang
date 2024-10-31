const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

pub fn main() !void {}

fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);

    const bytes_read = try file.readAll(buffer);
    assert(file_size == bytes_read);

    return buffer;
}

test "readfile" {
    const allocator = std.heap.page_allocator;

    const text = try readFile(allocator, "test.txt");

    try expect(std.mem.eql(u8, text, "writing"));
}
