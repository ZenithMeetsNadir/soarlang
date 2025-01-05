const std = @import("std");
const byteparser = @import("../parser/byteparser.zig");
const Stack = @import("./Stack.zig");

pub const GlobalError = error{
    CannotReference,
};

pub const word_size = @sizeOf(usize);

pub const float = switch (word_size) {
    4 => f32,
    8 => f64,
    else => f64,
};

pub const soar_lang_endian: std.builtin.Endian = .little;

// registers
pub const num_registers = 6;
pub const A = 0;
pub const B = A + word_size;
pub const C = B + word_size;
pub const D = C + word_size;
pub const E = D + word_size;
pub const F = E + word_size;

pub const global_mem_size = num_registers * word_size;

pub var global_mem: [global_mem_size]u8 = undefined;

const StrBlockT = u64;
pub fn squashStrBlock(str: []const u8) StrBlockT {
    if (str.len > @sizeOf(StrBlockT))
        return 0;

    var char_arr: [@sizeOf(StrBlockT)]u8 = undefined;
    std.mem.copyForwards(u8, &char_arr, str);

    return byteparser.assemb(StrBlockT, &char_arr, soar_lang_endian);
}

pub const EmbedPtr = struct {
    address: usize,
    is_global: bool,

    pub fn globalPtr(address: usize) EmbedPtr {
        return EmbedPtr{ .address = address, .is_global = true };
    }

    pub fn nonGlobalPtr(address: usize) EmbedPtr {
        return EmbedPtr{ .address = address, .is_global = false };
    }
};

pub fn referenceGlobal(global: []const u8) GlobalError!EmbedPtr {
    return switch (squashStrBlock(global)) {
        squashStrBlock("SP") => EmbedPtr.nonGlobalPtr(Stack.SP),
        squashStrBlock("FP") => EmbedPtr.nonGlobalPtr(Stack.FP),
        squashStrBlock("A") => EmbedPtr.globalPtr(A),
        squashStrBlock("B") => EmbedPtr.globalPtr(B),
        squashStrBlock("C") => EmbedPtr.globalPtr(C),
        squashStrBlock("D") => EmbedPtr.globalPtr(D),
        squashStrBlock("E") => EmbedPtr.globalPtr(E),
        squashStrBlock("F") => EmbedPtr.globalPtr(F),
        else => GlobalError.CannotReference,
    };
}
