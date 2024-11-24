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
pub const num_registers = 6;
pub const A = FP + @sizeOf(usize);
pub const B = A + @sizeOf(usize);
pub const C = B + @sizeOf(usize);
pub const D = C + @sizeOf(usize);
pub const E = D + @sizeOf(usize);
pub const F = E + @sizeOf(usize);

pub const GlobalError = error{
    CannotReference,
};

fn strEql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn referenceGlobal(global: []const u8) GlobalError!usize {
    if (strEql(global, "SP")) {
        return SP;
    } else if (strEql(global, "FP")) {
        return FP;
    } else if (strEql(global, "A")) {
        return A;
    } else if (strEql(global, "B")) {
        return B;
    } else if (strEql(global, "C")) {
        return C;
    } else if (strEql(global, "D")) {
        return D;
    } else if (strEql(global, "E")) {
        return E;
    } else if (strEql(global, "F")) {
        return F;
    }

    return GlobalError.CannotReference;
}

// init stack pointer
pub const SP_init_value = F + @sizeOf(usize);
