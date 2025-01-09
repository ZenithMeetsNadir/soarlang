const std = @import("std");
const math = std.math;
const globals = @import("./globals.zig");

const Stack = @This();

pub const Properties = struct {
    pub const return_address_offset: usize = globals.word_size;
    pub const first_arg_offset: usize = return_address_offset + globals.word_size;
};

pub const defaut_stack_size: usize = math.pow(usize, 2, 10);
pub var main_tape: [defaut_stack_size]u8 = undefined;

pub const SP: usize = 0;
pub const FP: usize = SP + globals.word_size;

// init stack pointer
pub const SP_init_value = FP + globals.word_size;

stack_tape: []u8,

pub fn construct() Stack!std.mem.Allocator.Error {
    const tape_alloc = try std.heap.page_allocator.alloc(u8, defaut_stack_size);
    return Stack{ .stack_tape = tape_alloc };
}

pub fn dispose(self: Stack) void {
    std.heap.page_allocator.free(self.stack_tape);
}
