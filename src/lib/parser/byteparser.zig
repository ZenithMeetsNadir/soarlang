const std = @import("std");
const Endian = std.builtin.Endian;

pub fn distr(comptime T: type, value: T, endianness: Endian) [@sizeOf(T)]u8 {
    return std.mem.toBytes(std.mem.nativeTo(T, value, endianness));
}

pub fn assemb(comptime T: type, bytes: []const u8, endianness: Endian) T {
    return std.mem.toNative(T, std.mem.bytesToValue(T, bytes), endianness);
}
