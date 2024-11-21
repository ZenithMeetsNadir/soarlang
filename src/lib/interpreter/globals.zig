const std = @import("std");

pub const float = switch (@sizeOf(isize)) {
    4 => f32,
    8 => f64,
    else => f64,
};

pub const soar_lang_endian: std.builtin.Endian = .little;

// pointers
pub const SP = 0;
pub const FP = SP + @sizeOf(usize);

// registers
pub const A = FP + @sizeOf(usize);
pub const B = A + @sizeOf(usize);
pub const C = B + @sizeOf(usize);
pub const D = C + @sizeOf(usize);
pub const E = D + @sizeOf(usize);
pub const F = E + @sizeOf(usize);

// init stack pointer
pub const SP_value = F + @sizeOf(usize);
