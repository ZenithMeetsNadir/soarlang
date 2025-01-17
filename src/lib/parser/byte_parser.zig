const std = @import("std");
const Endian = std.builtin.Endian;

pub fn distr(comptime T: type, value: T, endianness: Endian) [@sizeOf(T)]u8 {
    return std.mem.toBytes(std.mem.nativeTo(T, value, endianness));
}

pub fn assemb(comptime T: type, bytes: []const u8, endianness: Endian) T {
    return std.mem.toNative(T, std.mem.bytesToValue(T, bytes), endianness);
}

const StrBlockT = u64;
pub fn squashStrBlock(str: []const u8) StrBlockT {
    if (str.len > @sizeOf(StrBlockT))
        return 0;

    var char_arr: [@sizeOf(StrBlockT)]u8 = undefined;
    std.mem.copyForwards(u8, &char_arr, str);

    return assemb(StrBlockT, &char_arr, .big);
}
