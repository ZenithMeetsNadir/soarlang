const std = @import("std");
const byte_parser = @import("../parser/byte_parser.zig");
const squashStrBlock = byte_parser.squashStrBlock;
const Stack = @import("./Stack.zig");

pub const LabelHashMap = std.StringHashMap(ScopePtr);

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

pub const ScopePtr = struct {
    address: usize,
    is_global: bool,

    pub fn globalPtr(address: usize) ScopePtr {
        return ScopePtr{ .address = address, .is_global = true };
    }

    pub fn nonGlobalPtr(address: usize) ScopePtr {
        return ScopePtr{ .address = address, .is_global = false };
    }
};

pub fn referenceGlobal(global: []const u8) GlobalError!ScopePtr {
    return switch (squashStrBlock(global)) {
        squashStrBlock("SP") => ScopePtr.nonGlobalPtr(Stack.SP),
        squashStrBlock("FP") => ScopePtr.nonGlobalPtr(Stack.FP),
        squashStrBlock("RAMS") => ScopePtr.nonGlobalPtr(Stack.RAMS),
        squashStrBlock("SS") => ScopePtr.nonGlobalPtr(Stack.SS),
        squashStrBlock("A") => ScopePtr.globalPtr(A),
        squashStrBlock("B") => ScopePtr.globalPtr(B),
        squashStrBlock("C") => ScopePtr.globalPtr(C),
        squashStrBlock("D") => ScopePtr.globalPtr(D),
        squashStrBlock("E") => ScopePtr.globalPtr(E),
        squashStrBlock("F") => ScopePtr.globalPtr(F),
        else => GlobalError.CannotReference,
    };
}

pub var globalLabels: LabelHashMap = LabelHashMap.init(std.heap.page_allocator);
