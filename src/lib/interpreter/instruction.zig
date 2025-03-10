const std = @import("std");
const byte_parser = @import("../parser/byte_parser.zig");
const IR_parser = @import("../parser/IR_parser.zig");
const global = @import("global.zig");
const float = global.float;
const Stack = @import("./Stack.zig");

pub const Instruction = enum {
    // no args
    /// initialise SP
    init,
    /// allocate word on stack (increment SP by word size)
    resrv,
    /// declare a label
    label,
    /// else code block
    @"else",
    /// end of code block
    end,
    /// end of a while loop
    endwhile,
    /// break from a code block
    @"break",
    /// break from a while loop
    breakwh,
    /// call a function inside the current stack frame
    callraw,
    /// break from a function
    breakfn,
    /// tear down the current stack frame
    ret,
    /// exit program execution
    exit,

    // <address>
    /// allocate word on stack and store its address
    stlc,
    /// cast float to int
    cast,
    /// cast int to float
    castf,
    /// convert word to boolean
    bool,
    /// bitwise negate word
    not,
    /// increment word
    inc,
    /// decrementc word
    dec,
    /// increment by word size
    incws,
    /// decrement by word size
    decws,
    /// dereference word
    deref,

    // <address> <address>

    // <address> <address> <value>
    /// copy arbitrary number of bytes from address to address
    bytecpy,

    // <address> <value>
    /// set word at address
    set,
    /// allocate bytes on stack and store the address
    stlcsz,
    /// bitwise and word
    @"and",
    /// bitwise or word
    @"or",
    /// print bytes int to stderr
    ///
    /// deprecated: use `put%{size}` instead
    putsz,
    /// add to word at address
    add,
    /// subtract from word at address
    sub,
    /// multiply word at address
    mul,
    /// divide word at address
    div,
    /// word modulus division at adress
    mod,

    // <address> <value> <value>
    /// set bytes at address
    ///
    /// deprecated: use `set%{size}` instead
    setsz,

    // <address> <float>
    /// set float at address
    setf,

    // <value>
    /// print word to stderr
    put,
    /// print word to stderr in hex
    putx,
    /// allocate bytes on stack (increment SP by size)
    rsvsz,
    /// push word to stack (SET + RESRV)
    push,
    /// tear down stack
    pop,
    /// enter following code block if true (nonzero), jump to else block otherwise
    @"if",
    /// loop following code block until zero
    @"while",
    /// call a function and create a new stack frame for it, passing values in registers A-F as arguments, the first one being the return address of this function
    call,

    // <value> <value>
    /// enter following code block if equal words, jump to else block otherwise
    ifeql,
    /// enter following code block if not equal words, jump to else block otherwise
    ifnoeq,
    /// enter following code block if word1 is smaller that word2, jump to else block otherwise
    ifsmlr,
    /// enter following code block if word1 is greater that word2, jump to else block otherwise
    ifgrtr,
    /// enter following code block if word1 is smaller or equal that word2, jump to else block otherwise
    ifsmeq,
    /// enter following code block if word1 is greater or equal that word2, jump to else block otherwise
    ifgreq,
    /// push bytes to stack (SET + RSVSZ)
    ///
    /// deprecated: use `push%{size}` instead
    pushsz,
    /// determine whether words are equal; set f register
    eql,
    /// determine whether words are not equal; set f register
    noeq,
    /// determine whether word1 is smaller than word2; set e register
    smlr,
    /// determine whether word1 is greater than word2; set e register
    grtr,
    /// determine whether word1 is smaller or equal than word2; set d register
    smeq,
    /// determine whether word1 is greater or equal than word2; set d register
    greq,
    /// for testing purposes
    testeql,

    // <float>
    /// print float to console
    putf,

    pub fn fromString(instr_name: []const u8) ?Instruction {
        return std.meta.stringToEnum(Instruction, instr_name);
    }

    pub fn inRange(instr: Instruction, start_inc: Instruction, end_inc: Instruction) bool {
        const i: usize = @intFromEnum(instr);
        return i >= @intFromEnum(start_inc) and i <= @intFromEnum(end_inc);
    }

    pub fn noArgs(instr: Instruction) bool {
        return Instruction.inRange(instr, .init, .exit);
    }

    pub fn aArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .stlc, .setf);
    }

    pub fn aaArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .bytecpy, .bytecpy);
    }

    pub fn aavArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .bytecpy, .bytecpy);
    }

    pub fn avArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .set, .setsz);
    }

    pub fn avvArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .setsz, .setsz);
    }

    pub fn afArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .setf, .setf);
    }

    pub fn vArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .put, .testeql);
    }

    pub fn vvArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .ifeql, .testeql);
    }

    pub fn fArg(instr: Instruction) bool {
        return Instruction.inRange(instr, .putf, .putf);
    }

    pub fn beginsCodeBlock(instr: Instruction) bool {
        return switch (instr) {
            .@"if", .ifeql, .@"else", .@"while" => true,
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

pub fn wordBytes(tape: []const u8, address: usize) AddressError![]const u8 {
    if (address + @sizeOf(@TypeOf(address)) > tape.len)
        return AddressError.BadAddress;

    return tape[address .. address + global.word_size];
}

pub fn wordValue(tape: []const u8, address: usize) AddressError!isize {
    return byte_parser.assemb(isize, try wordBytes(tape, address), global.soar_lang_endian);
}

pub fn wordSized(tape: []const u8, address: usize, size: u8) AddressError!isize {
    if (size > global.word_size)
        return AddressError.BadAddress;

    const and_mask: isize = @bitCast(~@as(usize, 0) >> @intCast(8 * (global.word_size - size)));
    return try wordValue(tape, address) & and_mask;
}

pub fn word(tape: []const u8, address: usize, size: ?u8) AddressError!isize {
    return if (size == null) try wordValue(tape, address) else try wordSized(tape, address, size.?);
}

pub fn wordUnsigned(tape: []const u8, address: usize) AddressError!usize {
    return byte_parser.assemb(usize, try wordBytes(tape, address), global.soar_lang_endian);
}

pub fn wordFloat(tape: []const u8, address: usize) AddressError!float {
    return @bitCast(byte_parser.assemb(isize, try wordBytes(tape, address), global.soar_lang_endian));
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
    for (bytes, 0..) |byte, index| {
        to_tape[to_address + index] = byte;
    }
}

pub fn setWord(tape: []u8, address: usize, value: isize) AddressError!void {
    try setWordBytes(tape, address, byte_parser.distr(isize, value, global.soar_lang_endian));
}

pub fn setSized(tape: []u8, address: usize, value: isize, size: u8) AddressError!void {
    if (size > global.word_size)
        return AddressError.BadAddress;

    const and_mask: usize = ~@as(usize, 0) << @intCast(8 * size);
    try andWord(tape, address, @bitCast(and_mask), null);
    try orWord(tape, address, value, null);
}

pub fn set(tape: []u8, address: usize, value: isize, size: ?u8) AddressError!void {
    if (size == null) {
        try setWord(tape, address, value);
    } else try setSized(tape, address, value, size.?);
}

pub fn setUnsigned(tape: []u8, address: usize, value: usize) AddressError!void {
    try setWordBytes(tape, address, byte_parser.distr(usize, value, global.soar_lang_endian));
}

pub fn setFloat(tape: []u8, address: usize, value: float) AddressError!void {
    try setWordBytes(tape, address, byte_parser.distr(isize, @bitCast(value), global.soar_lang_endian));
}

pub fn toInt(tape: []u8, address: usize) AddressError!void {
    try setWord(tape, address, @intFromFloat(try wordFloat(tape, address)));
}

pub fn toFloat(tape: []u8, address: usize) AddressError!void {
    try setFloat(tape, address, @floatFromInt(try wordValue(tape, address)));
}

pub fn toBool(tape: []u8, address: usize, size: ?u8) AddressError!void {
    try set(tape, address, @intFromBool(try word(tape, address, size) != 0), size);
}

pub fn negateWord(tape: []u8, address: usize, size: ?u8) AddressError!void {
    try set(tape, address, ~(try word(tape, address, size)), size);
}

pub fn initTape(tape: []u8) AddressError!void {
    try setUnsigned(tape, Stack.SP, Stack.SP_init_value);
    try setUnsigned(tape, Stack.FP, Stack.SP_init_value);
    try setUnsigned(tape, Stack.RAMS, tape.len);
    try setUnsigned(tape, Stack.SS, Stack.SP_init_value);
}

pub fn andWord(tape: []u8, address: usize, value: isize, size: ?u8) AddressError!void {
    try set(tape, address, try word(tape, address, size) & value, size);
}

pub fn orWord(tape: []u8, address: usize, value: isize, size: ?u8) AddressError!void {
    try set(tape, address, try word(tape, address, size) | value, size);
}

pub fn addWord(tape: []u8, address: usize, value: isize, size: ?u8) AddressError!void {
    try set(tape, address, try word(tape, address, size) +% value, size);
}

pub fn subtractWord(tape: []u8, address: usize, value: isize, size: ?u8) AddressError!void {
    try addWord(tape, address, -value, size);
}

pub fn multiplyWord(tape: []u8, address: usize, value: isize, size: ?u8) AddressError!void {
    try set(tape, address, try word(tape, address, size) *% value, size);
}

pub fn divideWord(tape: []u8, address: usize, value: isize, size: ?u8) AddressError!void {
    try set(tape, address, std.math.divExact(isize, try word(tape, address, size), value) catch return AddressError.BadAddress, size);
}

pub fn modWord(tape: []u8, address: usize, value: isize, size: ?u8) AddressError!void {
    try set(tape, address, @mod(try word(tape, address, size), value), size);
}

pub fn incrementWord(tape: []u8, address: usize, size: ?u8) AddressError!void {
    try addWord(tape, address, 1, size);
}

pub fn decrementWord(tape: []u8, address: usize, size: ?u8) AddressError!void {
    try addWord(tape, address, -1, size);
}

pub fn incrementWSize(tape: []u8, address: usize, size: ?u8) AddressError!void {
    try addWord(tape, address, global.word_size, size);
}

pub fn decrementWSize(tape: []u8, address: usize, size: ?u8) AddressError!void {
    try addWord(tape, address, -global.word_size, size);
}

pub fn equal(tape: []u8, value1: isize, value2: isize, size: ?u8) AddressError!void {
    try set(tape, global.F, @intFromBool(value1 == value2), size);
}

pub fn notEqual(tape: []u8, value1: isize, value2: isize, size: ?u8) AddressError!void {
    try set(tape, global.F, @intFromBool(value1 != value2), size);
}

pub fn smaller(tape: []u8, value1: isize, value2: isize, size: ?u8) AddressError!void {
    try set(tape, global.E, @intFromBool(value1 < value2), size);
}

pub fn smallerOrEqual(tape: []u8, value1: isize, value2: isize, size: ?u8) AddressError!void {
    try set(tape, global.E, @intFromBool(value1 <= value2), size);
}

pub fn greater(tape: []u8, value1: isize, value2: isize, size: ?u8) AddressError!void {
    try set(tape, global.D, @intFromBool(value1 > value2), size);
}

pub fn greaterOrEqual(tape: []u8, value1: isize, value2: isize, size: ?u8) AddressError!void {
    try set(tape, global.D, @intFromBool(value1 >= value2), size);
}

pub fn dereferenceWord(tape: []u8, stack_tape: []const u8, address: usize) AddressError!void {
    const deref_addr = try wordUnsigned(tape, address);
    try setWord(tape, address, try wordValue(stack_tape, deref_addr));
}

pub fn reserve(tape: []u8) MemoryError!void {
    incrementWSize(tape, Stack.SP, null) catch return MemoryError.NotEnoughMemory;
}

pub fn reserveSized(tape: []u8, value: usize) MemoryError!void {
    addWord(tape, Stack.SP, @bitCast(value), null) catch return MemoryError.NotEnoughMemory;
}

pub fn stackAlloc(tape: []u8, stack_tape: []u8, address: usize) MemoryError!void {
    const sp_point = wordUnsigned(stack_tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
    setUnsigned(tape, address, sp_point) catch return MemoryError.NotEnoughMemory;
    try reserve(stack_tape);
}

pub fn stackAllocSized(tape: []u8, stack_tape: []u8, address: usize, value: usize) MemoryError!void {
    const sp_point = wordUnsigned(stack_tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
    setUnsigned(tape, address, sp_point) catch return MemoryError.NotEnoughMemory;
    try reserveSized(stack_tape, value);
}

pub fn push(tape: []u8, value: isize, size: ?u8) MemoryError!void {
    const sp_point = wordUnsigned(tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
    set(tape, sp_point, value, size) catch return MemoryError.NotEnoughMemory;
    try reserveSized(tape, @as(usize, size orelse global.word_size));
}

pub fn pushSized(tape: []u8, value: isize, size: u8) MemoryError!void {
    const sp_point = wordUnsigned(tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
    setSized(tape, sp_point, value, size) catch return MemoryError.NotEnoughMemory;
    try reserveSized(tape, size);
}

pub fn pop(tape: []u8, value: isize) AddressError!void {
    try subtractWord(tape, Stack.SP, value, null);
}

pub fn newFrame(tape: []u8) MemoryError!void {
    const fp_point = wordValue(tape, Stack.FP) catch return MemoryError.NotEnoughMemory;

    const sp_point = wordUnsigned(tape, Stack.SP) catch return MemoryError.NotEnoughMemory;
    setUnsigned(tape, Stack.FP, sp_point) catch return MemoryError.NotEnoughMemory;

    try push(tape, fp_point, null);
}

pub fn @"return"(tape: []u8) AddressError!void {
    const fp_point = try wordUnsigned(tape, Stack.FP);
    try setUnsigned(tape, Stack.SP, fp_point);

    const fp_ret = try wordUnsigned(tape, fp_point);
    try setUnsigned(tape, Stack.FP, fp_ret);
}

pub fn call(tape: []u8, arg_count: isize) MemoryError!void {
    if (arg_count > global.num_registers)
        return MemoryError.NotEnoughMemory;

    try newFrame(tape);

    var reg_addr: usize = global.A;
    var i: usize = 0;

    while (i < arg_count) : ({
        i += 1;
        reg_addr += global.word_size;
    }) {
        const reg_val = wordValue(&global.global_mem, reg_addr) catch return MemoryError.NotEnoughMemory;
        try push(tape, reg_val, null);
    }
}

pub fn getReturnAddress(tape: []const u8) AddressError!usize {
    const fp_point = try wordUnsigned(tape, Stack.FP);
    return fp_point + Stack.Properties.return_address_offset;
}

pub fn getArgAddress(tape: []const u8, arg_num: usize) AddressError!usize {
    const fp_point = try wordUnsigned(tape, Stack.FP);
    return fp_point + Stack.Properties.first_arg_offset + arg_num * global.word_size;
}
