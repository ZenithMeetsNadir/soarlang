const std = @import("std");
const math = std.math;
const global = @import("./global.zig");
const LabelHashMap = global.LabelHashMap;
const Stack = @This();

pub const Properties = struct {
    pub const return_address_offset: usize = global.word_size;
    pub const first_arg_offset: usize = global.word_size;
};

pub const defaut_stack_size: usize = math.pow(usize, 2, 10);

pub const SP: usize = 0;
pub const FP: usize = SP + global.word_size;

// memory space given to this process
pub const RAMS: usize = FP + global.word_size;

// static variables start from here (static space)
pub const SS: usize = RAMS + global.word_size;

// init stack pointer
pub const SP_init_value = SS + global.word_size;

stack_tape: []u8,
// local as in stack-unique
localLabels: LabelHashMap,
allocator: std.mem.Allocator,

pub fn construct(allocator: std.mem.Allocator) std.mem.Allocator.Error!Stack {
    const tape_alloc = try allocator.alloc(u8, defaut_stack_size);
    for (tape_alloc) |*byte| {
        byte.* = 0;
    }
    return Stack{ .stack_tape = tape_alloc, .localLabels = LabelHashMap.init(allocator), .allocator = allocator };
}

pub fn dispose(self: *Stack) void {
    self.allocator.free(self.stack_tape);
    self.localLabels.deinit();
}
