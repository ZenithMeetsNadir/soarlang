const std = @import("std");
const print = std.debug.print;

const IRparser = @import("../parser/IRparser.zig");
const InstructionIterator = IRparser.InstructionIterator;
const instruction = @import("instruction.zig");
const globals = @import("globals.zig");
const tape = &@import("tape.zig").tape;

const ArgumentError = error{
    CouldNotParse,
};

const InstructionError = error{
    WrongNumberOfArguments,
};

pub fn resolveValue(val_str: []const u8) (ArgumentError || instruction.AddressError)!isize {
    if (val_str.len == 0)
        return ArgumentError.CouldNotParse;

    var is_val_deref: bool = undefined;
    const val_str_cpy = blk: {
        if (val_str[0] == '[') {
            is_val_deref = true;
            break :blk val_str[1 .. val_str.len - 1];
        }

        break :blk val_str;
    };

    print("is_val_deref: {any}\n", .{is_val_deref});

    var value: isize = std.fmt.parseInt(isize, val_str_cpy, 0) catch |err| blk: {
        break :blk switch (err) {
            std.fmt.ParseIntError.Overflow => return ArgumentError.CouldNotParse,
            std.fmt.ParseIntError.InvalidCharacter => inv_char: {
                print("referencing global: {s}\n", .{val_str_cpy});
                const global_addr = globals.referenceGlobal(val_str_cpy) catch return ArgumentError.CouldNotParse;
                print("referenced global - address: {d}\n", .{global_addr});
                break :inv_char try instruction.wordValue(tape, global_addr);
            },
        };
    };

    print("value before possible dereference: {d}\n", .{value});

    if (is_val_deref) {
        value = try instruction.wordValue(tape, @bitCast(value));
        print("value after dereference: {d}\n", .{value});
    }

    return value;
}

pub fn resolveAddress(addr_str: []const u8) (ArgumentError || instruction.AddressError)!usize {
    if (addr_str.len == 0)
        return ArgumentError.CouldNotParse;

    var is_deref: bool = undefined;
    const addr_str_cpy = blk: {
        if (addr_str[0] == '[') {
            is_deref = true;
            break :blk addr_str[1 .. addr_str.len - 1];
        }

        break :blk addr_str;
    };

    print("is_deref: {any}\n", .{is_deref});

    var address: usize = std.fmt.parseUnsigned(usize, addr_str_cpy, 0) catch |err| blk: {
        break :blk switch (err) {
            std.fmt.ParseIntError.Overflow => return ArgumentError.CouldNotParse,
            std.fmt.ParseIntError.InvalidCharacter => globals.referenceGlobal(addr_str_cpy) catch return ArgumentError.CouldNotParse,
        };
    };

    print("address before possible dereference: {d}\n", .{address});

    if (is_deref) {
        address = try instruction.wordUnsigned(tape, address);
        print("address after dereference: {d}\n", .{address});
    }

    return address;
}

pub fn unwrapArgs(arg_iter: *IRparser.ArgumentIterator, comptime arg_count: usize) InstructionError![arg_count][]const u8 {
    var args: [arg_count][]const u8 = undefined;

    var index: usize = 0;
    while (arg_iter.next()) |arg| : (index += 1) {
        if (index >= args.len)
            return InstructionError.WrongNumberOfArguments;

        args[index] = arg;
    }

    if (index < args.len)
        return InstructionError.WrongNumberOfArguments;

    return args;
}

pub fn interpret(instructions: *InstructionIterator) !void {
    try instruction.initTape(tape);

    var instr_null = instructions.next();
    while (instr_null != null) : (instr_null = instructions.next()) {
        var instr = instr_null.?;
        const instr_name = instr.first();

        if (std.mem.eql(u8, instr_name, "SET")) {
            print("<SET instruction>\n", .{});
            const args = try unwrapArgs(&instr, 2);
            print("unwrapped args: {s}; {s}\n", .{ args[0], args[1] });
            const address = try resolveAddress(args[0]);
            print("resolved address: {d}\n", .{address});
            const value = try resolveValue(args[1]);
            print("resolved value: {d}\n", .{value});

            try instruction.setWord(tape, address, value);
            print("value at address {d}: {d}\n", .{ address, try instruction.wordValue(tape, address) });
            print("</SET intruction>\n\n", .{});
        } else if (std.mem.eql(u8, instr_name, "PUSH")) {
            print("<PUSH instruction>\n", .{});
            const args = try unwrapArgs(&instr, 1);
            print("unwrapped args: {s}\n", .{args[0]});
            const value = try resolveValue(args[0]);
            print("resolved value: {d}\n", .{value});

            try instruction.push(tape, value);
            print("</PUSH instruction>\n\n", .{});
        }
    }

    print("SP: {d}\n", .{try instruction.wordUnsigned(tape, globals.SP)});
}
