const std = @import("std");
const byteparser = @import("../parser/byteparser.zig");
const globals = @import("globals.zig");
const float = globals.float;

pub const Instruction = enum {
    // no args
    /// allocate word on stack (increment SP by word size)
    RESRV,

    // <address>
    /// cast float to int
    CAST,
    /// cast int to float
    CASTF,
    /// increment word
    INC,
    /// decrementc word
    DEC,
    /// increment by word size
    INCWS,
    /// decrement by word size
    DECWS,

    // <address> <address>

    // <address> <value>
    /// set word at address
    SET,
    /// set float at address
    SETF,
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

    // <value>
    /// print word to stderr
    PUT,
    /// print float to console
    PUTF,
    /// push word to stack (SET + RESRV)
    PUSH,

    pub fn fromString(instr_name: []const u8) ?Instruction {
        return std.meta.stringToEnum(Instruction, instr_name);
    }

    pub fn inRange(instr: Instruction, start_inc: Instruction, end_inc: Instruction) bool {
        const i: usize = @intFromEnum(instr);
        return i >= @intFromEnum(start_inc) and i <= @intFromEnum(end_inc);
    }

    pub fn noArgs(instr: Instruction) bool {
        return Instruction.inRange(instr, .RESRV, .RESRV);
    }

    pub fn aArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .CAST, .MOD);
    }

    pub fn avArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .SET, .MOD);
    }

    pub fn vArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .PUT, .PUSH);
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

pub fn initTape(tape: []u8) AddressError!void {
    try setUnsigned(tape, globals.SP, globals.SP_value);
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

pub fn decrementWSize(tape: []u8, address: usize) !void {
    try addWord(tape, address, -@sizeOf(usize));
}

pub fn reserve(tape: []u8) MemoryError!void {
    incrementWSize(tape, globals.SP) catch return MemoryError.NotEnoughMemory;
}

pub fn push(tape: []u8, value: isize) MemoryError!void {
    const sp_addr = wordUnsigned(tape, globals.SP) catch return MemoryError.NotEnoughMemory;
    setWord(tape, sp_addr, value) catch return MemoryError.NotEnoughMemory;
    try reserve(tape);
}
