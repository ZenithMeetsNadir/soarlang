const std = @import("std");
const byteparser = @import("../parser/byteparser.zig");
const IRparser = @import("../parser/IRparser.zig");
const globals = @import("globals.zig");
const float = globals.float;
const Stack = @import("./Stack.zig");

pub const Instruction = enum {
    // no args
    /// initialise SP
    INIT,
    /// allocate word on stack (increment SP by word size)
    RESRV,
    /// else code block
    ELSE,
    /// end of code block
    END,
    /// end of a while loop
    ENDWHILE,
    /// break from a code block
    BREAK,
    /// break from a while loop
    BREAKWH,
    /// call a function inside the current stack frame
    CALLRAW,
    /// break from a function
    BREAKFN,
    /// tear down the current stack frame
    RET,
    /// exit program execution
    EXIT,

    // <address>
    /// allocate word on stack and store its address
    STALLOC,
    /// cast float to int
    CAST,
    /// cast int to float
    CASTF,
    /// convert word to boolean
    BOOL,
    /// bitwise negate word
    NOT,
    /// increment word
    INC,
    /// decrementc word
    DEC,
    /// increment by word size
    INCWS,
    /// decrement by word size
    DECWS,
    /// dereference word
    DEREF,

    // <address> <address>

    // <address> <address> <value>
    /// copy arbitrary number of byte from address to address
    BYTECPY,

    // <address> <value>
    /// set word at address
    SET,
    /// allocate bytes on stack and store the address
    STLCSZ,
    /// bitwise and word
    AND,
    /// bitwise or word
    OR,
    /// print int to stderr
    PUTSZ,
    /// add to word at address
    ADD,
    /// subtract from word at address
    SUB,
    /// multiply word at address
    MUL,
    /// divide word at address
    DIV,
    /// word modulus division at adress
    MOD,

    // <address> <value> <value>
    /// set bytes at address
    SETSZ,
    /// determine whether words are equal
    EQL,
    /// determine whether word1 is smaller than word2
    SMLR,
    /// determine whether word1 is greater than word2
    GRTR,

    // <address> <float>
    /// set float at address
    SETF,

    // <value>
    /// print word to stderr
    PUT,
    /// allocate bytes on stak (increment SP by size)
    RSVSZ,
    /// push word to stack (SET + RESRV)
    PUSH,
    /// enter following code block if true, jump to else block otherwise
    IF,
    /// loop following code block until false
    WHILE,
    /// call a function and create a new stack frame for it, passing values in registers A-F as arguments, the first one being the return address of this function
    CALL,

    // <value> <value>
    /// enter following code block if equal words, jump to else block otherwise
    IFEQL,
    /// enter following code block if word1 is smaller that word2, jump to else block otherwise
    IFSMLR,
    /// enter following code block if word1 is greater that word2, jump to else block otherwise
    IFGRTR,
    /// push bytes to stack (SET + RSVSZ)
    PUSHSZ,
    /// for testing purposes
    TESTEQL,

    // <float>
    /// print float to console
    PUTF,

    pub fn fromString(instr_name: []const u8) ?Instruction {
        return std.meta.stringToEnum(Instruction, instr_name);
    }

    pub fn inRange(instr: Instruction, start_inc: Instruction, end_inc: Instruction) bool {
        const i: usize = @intFromEnum(instr);
        return i >= @intFromEnum(start_inc) and i <= @intFromEnum(end_inc);
    }

    pub fn noArgs(instr: Instruction) bool {
        return Instruction.inRange(instr, .INIT, .EXIT);
    }

    pub fn aArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .STALLOC, .SETF);
    }

    pub fn aaArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .BYTECPY, .BYTECPY);
    }

    pub fn aavArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .BYTECPY, .BYTECPY);
    }

    pub fn avArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .SET, .GRTR);
    }

    pub fn avvArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .SETSZ, .GRTR);
    }

    pub fn afArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .SETF, .SETF);
    }

    pub fn vArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .PUT, .TESTEQL);
    }

    pub fn vvArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .IFEQL, .TESTEQL);
    }

    pub fn fArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .PUTF, .PUTF);
    }

    pub fn beginsCodeBlock(instr: Instruction) bool {
        return switch (instr) {
            .IF, .IFEQL, .ELSE, .WHILE => true,
            else => false,
        };
    }
};

pub const AddressError = error{
    BadAddress,
};

pub const MemoryError = error{
    NotEnoughMemory,
};

pub fn word(tape: []const u8, address: usize) AddressError![]const u8 {
    if (address + @sizeOf(@TypeOf(address)) > tape.len)
        return AddressError.BadAddress;

    return tape[address .. address + globals.word_size];
}

pub fn wordValue(tape: []const u8, address: usize) AddressError!isize {
    return byteparser.assemb(isize, try word(tape, address), globals.soar_lang_endian);
}

pub fn wordSized(tape: []const u8, address: usize, size: u8) AddressError!isize {
    if (size > globals.word_size)
        return AddressError.BadAddress;

    const and_mask: isize = @bitCast(std.math.pow(usize, 2, @as(usize, size)) - 1);
    return try wordValue(tape, address) & and_mask;
}

pub fn wordUnsigned(tape: []const u8, address: usize) AddressError!usize {
    return byteparser.assemb(usize, try word(tape, address), globals.soar_lang_endian);
}

pub fn wordFloat(tape: []const u8, address: usize) AddressError!float {
    return @bitCast(byteparser.assemb(isize, try word(tape, address), globals.soar_lang_endian));
}

pub fn setWordBytes(tape: []u8, address: usize, bytes: [@sizeOf(@TypeOf(address))]u8) AddressError!void {
    if (address > tape.len - @sizeOf(@TypeOf(address)))
        return AddressError.BadAddress;

    for (&bytes, 0..) |byte, i| {
        tape[address + i] = byte;
    }
}

pub fn copyBytes(from_tape: []const u8, from_address: usize, to_tape: []u8, to_address: usize, num_bytes: usize) AddressError!void {
    if (to_address + num_bytes > to_tape.len or from_address + num_bytes > from_tape.len)
        return AddressError.BadAddress;

    const bytes = from_tape[from_address .. from_address + num_bytes];
    for (bytes, to_address..) |byte, index| {
        to_tape[index] = byte;
    }
}

pub fn setWord(tape: []u8, address: usize, value: isize) AddressError!void {
    try setWordBytes(tape, address, byteparser.distr(isize, value, globals.soar_lang_endian));
}

pub fn setWordSized(tape: []u8, address: usize, size: u8, value: isize) AddressError!void {
    if (size > globals.word_size)
        return AddressError.BadAddress;

    std.debug.print("{b}", .{try wordValue(tape, address)});

    const and_mask: usize = ~(std.math.pow(usize, 2, @as(usize, size)) - 1);
    try andWord(tape, address, @bitCast(and_mask));
    try orWord(tape, address, value);

    std.debug.print(" -> {b}\n\r", .{try wordValue(tape, address)});
}

pub fn setUnsigned(tape: []u8, address: usize, value: usize) AddressError!void {
    try setWordBytes(tape, address, byteparser.distr(usize, value, globals.soar_lang_endian));
}

pub fn setFloat(tape: []u8, address: usize, value: float) AddressError!void {
    try setWordBytes(tape, address, byteparser.distr(isize, @bitCast(value), globals.soar_lang_endian));
}

pub fn toInt(tape: []u8, address: usize) AddressError!void {
    try setWord(tape, address, @intFromFloat(try wordFloat(tape, address)));
}

pub fn toFloat(tape: []u8, address: usize) AddressError!void {
    try setFloat(tape, address, @floatFromInt(try wordValue(tape, address)));
}

pub fn toBool(tape: []u8, address: usize) AddressError!void {
    try setWord(tape, address, @intFromBool(try wordValue(tape, address) != 0));
}

pub fn negateWord(tape: []u8, address: usize) AddressError!void {
    try setWord(tape, address, ~(try wordValue(tape, address)));
}

pub fn initTape(tape: []u8) AddressError!void {
    try setUnsigned(tape, Stack.SP, Stack.SP_init_value);
    try setUnsigned(tape, Stack.FP, Stack.SP_init_value);
}

pub fn andWord(tape: []u8, address: usize, value: isize) AddressError!void {
    try setWord(tape, address, try wordValue(tape, address) & value);
}

pub fn orWord(tape: []u8, address: usize, value: isize) AddressError!void {
    try setWord(tape, address, try wordValue(tape, address) | value);
}

pub fn addWord(tape: []u8, address: usize, value: isize) AddressError!void {
    try setWord(tape, address, try wordValue(tape, address) +% value);
}

pub fn subtractWord(tape: []u8, address: usize, value: isize) AddressError!void {
    try addWord(tape, address, -value);
}

pub fn multiplyWord(tape: []u8, address: usize, value: isize) AddressError!void {
    try setWord(tape, address, try wordValue(tape, address) *% value);
}

pub fn divideWord(tape: []u8, address: usize, value: isize) AddressError!void {
    try setWord(tape, address, @divExact(try wordValue(tape, address), value));
}

pub fn modWord(tape: []u8, address: usize, value: isize) AddressError!void {
    try setWord(tape, address, @mod(try wordValue(tape, address), value));
}

pub fn incrementWord(tape: []u8, address: usize) AddressError!void {
    try addWord(tape, address, 1);
}

pub fn decrementWord(tape: []u8, address: usize) AddressError!void {
    try addWord(tape, address, -1);
}

pub fn incrementWSize(tape: []u8, address: usize) AddressError!void {
    try addWord(tape, address, globals.word_size);
}

pub fn decrementWSize(tape: []u8, address: usize) AddressError!void {
    try addWord(tape, address, -globals.word_size);
}

pub fn equal(tape: []u8, address: usize, value1: isize, value2: isize) AddressError!void {
    try setWord(tape, address, @intFromBool(value1 == value2));
}

pub fn smaller(tape: []u8, address: usize, value1: isize, value2: isize) AddressError!void {
    try setWord(tape, address, @intFromBool(value1 < value2));
}

pub fn greater(tape: []u8, address: usize, value1: isize, value2: isize) AddressError!void {
    try setWord(tape, address, @intFromBool(value1 > value2));
}

pub fn dereferenceWord(tape: []u8, stack_tape: []const u8, address: usize) AddressError!void {
    const deref_addr = try wordUnsigned(tape, address);
    try setWord(tape, address, try wordValue(stack_tape, deref_addr));
}

pub fn reserve(tape: []u8) MemoryError!void {
    incrementWSize(tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
}

pub fn reserveSized(tape: []u8, size: u8) MemoryError!void {
    addWord(tape, Stack.SP, @as(isize, size)) catch return MemoryError.NotEnoughMemory;
}

pub fn stackAlloc(tape: []u8, stack_tape: []u8, address: usize) MemoryError!void {
    const sp_point = wordUnsigned(stack_tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
    setUnsigned(tape, address, sp_point) catch return MemoryError.NotEnoughMemory;
    try reserve(stack_tape);
}

pub fn stackAllocSized(tape: []u8, stack_tape: []u8, address: usize, size: u8) MemoryError!void {
    const sp_point = wordUnsigned(stack_tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
    setUnsigned(tape, address, sp_point) catch return MemoryError.NotEnoughMemory;
    try reserveSized(stack_tape, size);
}

pub fn push(tape: []u8, value: isize) MemoryError!void {
    const sp_point = wordUnsigned(tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
    setWord(tape, sp_point, value) catch return MemoryError.NotEnoughMemory;
    try reserve(tape);
}

pub fn pushSized(tape: []u8, size: u8, value: isize) MemoryError!void {
    const sp_point = wordUnsigned(tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
    setWordSized(tape, sp_point, size, value) catch return MemoryError.NotEnoughMemory;
    try reserveSized(tape, size);
}

pub fn call(tape: []u8, arg_count: isize) MemoryError!void {
    if (arg_count > globals.num_registers)
        return MemoryError.NotEnoughMemory;

    const fp_point = wordValue(tape, Stack.FP) catch return MemoryError.NotEnoughMemory;

    const sp_point = wordUnsigned(tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
    setUnsigned(tape, Stack.FP, sp_point) catch return MemoryError.NotEnoughMemory;

    try push(tape, fp_point);

    var reg_addr: usize = globals.A;
    var i: usize = 0;

    while (i < arg_count) : ({
        i += 1;
        reg_addr += globals.word_size;
    }) {
        const reg_val = wordValue(&globals.global_mem, reg_addr) catch return MemoryError.NotEnoughMemory;
        try push(tape, reg_val);
    }
}

pub fn @"return"(tape: []u8) AddressError!void {
    const fp_point = try wordUnsigned(tape, Stack.FP);
    try setUnsigned(tape, Stack.SP, fp_point);

    const fp_ret = try wordUnsigned(tape, fp_point);
    try setUnsigned(tape, Stack.FP, fp_ret);
}

pub fn getReturnAddress(tape: []const u8) AddressError!usize {
    const fp_point = try wordUnsigned(tape, Stack.FP);
    return fp_point + Stack.Properties.return_address_offset;
}

pub fn getArgAddress(tape: []const u8, arg_num: usize) AddressError!usize {
    const fp_point = try wordUnsigned(tape, Stack.FP);
    return fp_point + Stack.Properties.first_arg_offset + arg_num * globals.word_size;
}
