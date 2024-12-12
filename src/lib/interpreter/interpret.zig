const std = @import("std");
const print = std.debug.print;

const byteparser = @import("../parser/byteparser.zig");
const IRparser = @import("../parser/IRparser.zig");
const InstructionIterator = IRparser.InstructionIterator;
const SourceObject = @import("SourceObject.zig");
const FunctionGetError = SourceObject.FunctionGetError;
const instruction = @import("instruction.zig");
const AddressError = instruction.AddressError;
const MemoryError = instruction.MemoryError;
const globals = @import("globals.zig");
const float = globals.float;

const ArgumentError = error{
    CouldNotParse,
};

const OffsetError = error{
    NoOffset,
};

const InstructionError = error{
    WrongNumberOfArguments,
};

const ExecutionInterruptionError = error{
    ExecutionAborted,
    FunctionReturned,
};

const InterpretError = AddressError || MemoryError || ExecutionInterruptionError || InstructionError || ArgumentError || FunctionGetError;

fn condDeref(arg: []const u8, store_is_deref: *bool) []const u8 {
    if (arg[0] == '[') {
        store_is_deref.* = true;

        var arg_iter = std.mem.splitScalar(u8, arg[1..], ']');
        return arg_iter.first();
    }

    return arg;
}

fn constOffset(str: []const u8) OffsetError!isize {
    var offset_iter = std.mem.splitScalar(u8, str, ']');

    _ = offset_iter.first();
    const offset_str = offset_iter.next() orelse return OffsetError.NoOffset;
    return std.fmt.parseInt(isize, offset_str, 0) catch return OffsetError.NoOffset;
}

pub fn resolveValue(tape: []const u8, val_str: []const u8) (ArgumentError || instruction.AddressError)!isize {
    if (val_str.len == 0)
        return ArgumentError.CouldNotParse;

    var deref_value: bool = false;
    const val_str_res = condDeref(val_str, &deref_value);

    print("\t\tderef_value: {any}\n", .{deref_value});

    var value: isize = std.fmt.parseInt(isize, val_str_res, 0) catch |err| blk: {
        break :blk switch (err) {
            std.fmt.ParseIntError.Overflow => return ArgumentError.CouldNotParse,
            std.fmt.ParseIntError.InvalidCharacter => inv_char: {
                print("\t\treferencing global: {s}\n", .{val_str_res});
                const global_addr = globals.referenceGlobal(val_str_res) catch return ArgumentError.CouldNotParse;
                print("\t\treferenced global - address: {d}\n", .{global_addr});
                break :inv_char try instruction.wordValue(tape, global_addr);
            },
        };
    };

    print("\t\tvalue: {d}\n", .{value});

    value += constOffset(val_str) catch 0;

    print("\t\tvalue after offset reslolution: {d}\n", .{value});

    if (deref_value) {
        value = try instruction.wordValue(tape, @bitCast(value));
        print("\t\tvalue after dereference: {d}\n", .{value});
    }

    return value;
}

pub fn resolveFloat(tape: []const u8, float_str: []const u8) (ArgumentError || instruction.AddressError)!float {
    if (float_str.len == 0)
        return ArgumentError.CouldNotParse;

    const flt: float = std.fmt.parseFloat(float, float_str) catch @bitCast(try resolveValue(tape, float_str));

    print("\t\tfloat: {d}\n", .{flt});

    return flt;
}

pub fn resolveAddress(tape: []const u8, addr_str: []const u8) (ArgumentError || instruction.AddressError)!usize {
    if (addr_str.len == 0)
        return ArgumentError.CouldNotParse;

    var deref: bool = false;
    const addr_str_res = condDeref(addr_str, &deref);

    print("\t\tderef: {any}\n", .{deref});

    var address: usize = std.fmt.parseUnsigned(usize, addr_str_res, 0) catch |err| blk: {
        break :blk switch (err) {
            std.fmt.ParseIntError.Overflow => return ArgumentError.CouldNotParse,
            std.fmt.ParseIntError.InvalidCharacter => inv_char: {
                print("\t\treferencing global: {s}\n", .{addr_str_res});
                const global_addr = globals.referenceGlobal(addr_str_res) catch return ArgumentError.CouldNotParse;
                print("\t\treferenced global - address: {d}\n", .{global_addr});
                break :inv_char global_addr;
            },
        };
    };

    print("\t\taddress: {d}\n", .{address});

    if (deref) {
        address = try instruction.wordUnsigned(tape, address);
        print("\t\taddress after dereference: {d}\n", .{address});
    }

    address +%= @bitCast(constOffset(addr_str) catch 0);

    print("\t\taddress after offset resolution: {d}\n", .{address});

    return address;
}

pub fn unwrapArgs(arg_iter: *IRparser.ArgumentIterator, comptime arg_count: usize) InstructionError![arg_count][]const u8 {
    var args: [arg_count][]const u8 = undefined;

    var index: usize = 0;
    while (arg_iter.peek()) |arg| : (index += 1) {
        if (index >= args.len)
            return args;

        _ = arg_iter.next();

        args[index] = arg;
    }

    if (index < args.len)
        return InstructionError.WrongNumberOfArguments;

    return args;
}

pub fn breakCodeBlock(instr_iter: *InstructionIterator) void {
    var open_blocks: usize = 0;

    while (instr_iter.next()) |arg_iter| {
        var arg_iter_mut = arg_iter;
        const instr_name = arg_iter_mut.first() orelse continue;

        const instr = instruction.Instruction.fromString(instr_name) orelse continue;

        switch (instr) {
            .IFEQL, .ELSE => open_blocks += 1,
            .END => {
                if (open_blocks > 0) {
                    open_blocks -= 1;
                } else break;
            },
            else => {},
        }
    }
}

pub fn interpretCodeBlock(instr_iter: *InstructionIterator, source_obj_ref: *const SourceObject) InterpretError!void {
    const code_block_iter = instr_iter.code_block;

    try interpret(instr_iter.continueCodeBlockIterator(), source_obj_ref);

    if (!code_block_iter)
        _ = instr_iter.continueInstructionIterator();
}

pub fn interpretIf(condition: bool, instr_iter: *InstructionIterator, source_obj_ref: *const SourceObject) InterpretError!void {
    if (condition) {
        try interpretCodeBlock(instr_iter, source_obj_ref);

        const arg_iter = instr_iter.peek() orelse return;
        if (std.mem.eql(u8, arg_iter.peekInstrName() orelse return, @tagName(instruction.Instruction.ELSE)))
            breakCodeBlock(instr_iter);
    } else breakCodeBlock(instr_iter);
}

pub fn callFunc(func_instr_iter: *InstructionIterator, source_obj_ref: *const SourceObject) InterpretError!void {
    interpret(func_instr_iter, source_obj_ref) catch |err| switch (err) {
        ExecutionInterruptionError.FunctionReturned => {},
        else => return err,
    };
}

pub fn interpretSourceObj(source_obj: *SourceObject) InterpretError!void {
    try interpret(&source_obj.instr_iter, source_obj);
}

pub fn interpret(instr_iter: *InstructionIterator, source_obj_ref: *const SourceObject) InterpretError!void {
    const tape = source_obj_ref.tape;

    while (instr_iter.next()) |arg_iter| {
        var arg_iter_mut = arg_iter;
        const instr_name = arg_iter_mut.first() orelse continue;
        const instr = instruction.Instruction.fromString(instr_name) orelse continue;
        print("\n<instruction: {s}>\n", .{@tagName(instr)});

        if (instruction.Instruction.noArgs(instr)) {
            switch (instr) {
                .INIT => try instruction.initTape(tape),
                .RESRV => try instruction.reserve(tape),
                .ELSE => try interpretCodeBlock(instr_iter, source_obj_ref),
                .END => {},
                .CALLRAW => {
                    const args = try unwrapArgs(&arg_iter_mut, 1);
                    const func_name = args[0];
                    print("\t<arg1: {s}>\n", .{func_name});

                    var func = try source_obj_ref.getFunc(func_name);
                    print("\t\tcalling: {s}\n", .{func_name});
                    try callFunc(&func, source_obj_ref);
                },
                .BREAK => breakCodeBlock(instr_iter.continueInstructionIterator()),
                // I actually hace no idea if BREAKFN is working, might test it as soon as I need its functionality.
                // Of What I can recall, it had issues when used inside a code block.
                .BREAKFN => return ExecutionInterruptionError.FunctionReturned,
                .RET => try instruction.@"return"(tape),
                .EXIT => return ExecutionInterruptionError.ExecutionAborted,
                else => unreachable,
            }
        } else if (instruction.Instruction.aArg(instr)) {
            var args = try unwrapArgs(&arg_iter_mut, 1);
            print("\t<arg1: {s}>\n", .{args[0]});
            const address = try resolveAddress(tape, args[0]);

            switch (instr) {
                .STALLOC => try instruction.stackAlloc(tape, address),
                .CAST => try instruction.toInt(tape, address),
                .CASTF => try instruction.toFloat(tape, address),
                .BOOL => try instruction.toBool(tape, address),
                .NOT => try instruction.negateWord(tape, address),
                .INC => try instruction.incrementWord(tape, address),
                .DEC => try instruction.decrementWord(tape, address),
                .INCWS => try instruction.incrementWSize(tape, address),
                .DECWS => try instruction.decrementWSize(tape, address),
                .DEREF => try instruction.dereferenceWord(tape, address),
                else => {
                    if (instruction.Instruction.avArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        print("\t<arg2: {s}>\n", .{args[0]});
                        const value = try resolveValue(tape, args[0]);

                        switch (instr) {
                            .SET => try instruction.setWord(tape, address, value),
                            .AND => try instruction.andWord(tape, address, value),
                            .OR => try instruction.orWord(tape, address, value),
                            .ADD => try instruction.addWord(tape, address, value),
                            .SUB => try instruction.subtractWord(tape, address, value),
                            .MUL => try instruction.multiplyWord(tape, address, value),
                            .DIV => try instruction.divideWord(tape, address, value),
                            .MOD => try instruction.modWord(tape, address, @bitCast(value)),
                            else => unreachable,
                        }
                    } else if (instruction.Instruction.afArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        print("\t<arg2: {s}>\n", .{args[0]});
                        const flt = try resolveFloat(tape, args[0]);

                        switch (instr) {
                            .SETF => try instruction.setFloat(tape, address, flt),
                            else => unreachable,
                        }
                    }
                },
            }
        } else if (instruction.Instruction.vArg(instr)) {
            var args = try unwrapArgs(&arg_iter_mut, 1);
            print("\t<arg1: {s}>\n", .{args[0]});
            var value = try resolveValue(tape, args[0]);

            switch (instr) {
                .PUT => print("{any}\n", .{value}),
                .PUSH => try instruction.push(tape, value),
                .IF => try interpretIf(value != 0, instr_iter, source_obj_ref),
                .WHILE => {
                    while (value != 0) : (value = try resolveValue(tape, args[0])) {
                        var code_block_start = instr_iter.*;
                        try interpretCodeBlock(&code_block_start, source_obj_ref);
                        print("\n<while loop condition>\n", .{});
                        print("\t<arg1: {s}>\n", .{args[0]});
                    }

                    breakCodeBlock(instr_iter);
                },
                .CALL => {
                    try instruction.call(tape, value);

                    args = try unwrapArgs(&arg_iter_mut, 1);
                    const func_name = args[0];
                    print("\t<arg2: {s}>\n", .{func_name});

                    var func = try source_obj_ref.getFunc(func_name);
                    print("\t\tcalling: {s}\n", .{func_name});
                    try callFunc(&func, source_obj_ref);
                },
                else => {
                    if (instruction.Instruction.vvArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        print("\t<arg2: {s}>\n", .{args[0]});
                        const value2 = try resolveValue(tape, args[0]);

                        switch (instr) {
                            .IFEQL => try interpretIf(value == value2, instr_iter, source_obj_ref),
                            else => unreachable,
                        }
                    }
                },
            }
        } else if (instruction.Instruction.fArg(instr)) {
            const args = try unwrapArgs(&arg_iter_mut, 1);
            print("\t<arg1: {s}>\n", .{args[0]});
            const flt = try resolveFloat(tape, args[0]);

            switch (instr) {
                .PUTF => print("{d}\n", .{flt}),
                else => unreachable,
            }
        }
    }
}
