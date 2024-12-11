const std = @import("std");
const byteparser = @import("../parser/byteparser.zig");
const IRparser = @import("../parser/IRparser.zig");
const globals = @import("globals.zig");
const float = globals.float;

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
    /// break from a code block
    BREAK,
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

    // <address> <value>
    /// set word at address
    SET,
    /// bitwise and to word
    AND,
    /// bitwise or to word
    OR,
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

    // <address> <float>
    /// set float at address
    SETF,

    // <value>
    /// print word to stderr
    PUT,
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

    pub fn avArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .SET, .MOD);
    }

    pub fn afArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .SETF, .SETF);
    }

    pub fn vArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .PUT, .IFEQL);
    }

    pub fn vvArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .IFEQL, .IFEQL);
    }

    pub fn fArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .PUTF, .PUTF);
    }
};

pub const AddressError = error{
    BadAddress,
};

pub const MemoryError = error{
    NotEnoughMemory,
};

pub fn word(tape: []const u8, address: usize) AddressError![]const u8 {
    if (address > tape.len - @sizeOf(@TypeOf(address)))
        return AddressError.BadAddress;

    return tape[address .. address + @sizeOf(usize)];
}

pub fn wordValue(tape: []const u8, address: usize) AddressError!isize {
    return byteparser.assemb(isize, try word(tape, address), globals.soar_lang_endian);
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

pub fn setWord(tape: []u8, address: usize, value: isize) AddressError!void {
    try setWordBytes(tape, address, byteparser.distr(isize, value, globals.soar_lang_endian));
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
    try setUnsigned(tape, globals.SP, globals.SP_init_value);
    try setUnsigned(tape, globals.FP, globals.SP_init_value);
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
    try addWord(tape, address, @sizeOf(usize));
}

pub fn decrementWSize(tape: []u8, address: usize) AddressError!void {
    try addWord(tape, address, -@sizeOf(usize));
}

pub fn dereferenceWord(tape: []u8, address: usize) AddressError!void {
    const deref_addr = try wordUnsigned(tape, address);
    try setWord(tape, address, try wordValue(tape, deref_addr));
}

pub fn reserve(tape: []u8) MemoryError!void {
    incrementWSize(tape, globals.SP) catch return MemoryError.NotEnoughMemory;
}

pub fn stackAlloc(tape: []u8, address: usize) MemoryError!void {
    setUnsigned(tape, address, globals.SP) catch return MemoryError.NotEnoughMemory;
    try reserve(tape);
}

pub fn push(tape: []u8, value: isize) MemoryError!void {
    const sp_point = wordUnsigned(tape, globals.SP) catch return MemoryError.NotEnoughMemory;
    setWord(tape, sp_point, value) catch return MemoryError.NotEnoughMemory;
    try reserve(tape);
}

pub fn call(tape: []u8, arg_count: isize) MemoryError!void {
    if (arg_count > globals.num_registers)
        return MemoryError.NotEnoughMemory;

    const fp_point = wordValue(tape, globals.FP) catch return MemoryError.NotEnoughMemory;

    const sp_point = wordUnsigned(tape, globals.SP) catch return MemoryError.NotEnoughMemory;
    setUnsigned(tape, globals.FP, sp_point) catch return MemoryError.NotEnoughMemory;

    try push(tape, fp_point);

    var reg_addr: usize = globals.A;
    var i: usize = 0;

    while (i < arg_count) : ({
        i += 1;
        reg_addr += @sizeOf(usize);
    }) {
        const reg_val = wordValue(tape, reg_addr) catch return MemoryError.NotEnoughMemory;
        try push(tape, reg_val);
    }
}

pub fn @"return"(tape: []u8) AddressError!void {
    const fp_point = try wordUnsigned(tape, globals.FP);
    try setUnsigned(tape, globals.SP, fp_point);

    const fp_ret = try wordUnsigned(tape, fp_point);
    try setUnsigned(tape, globals.FP, fp_ret);
}
