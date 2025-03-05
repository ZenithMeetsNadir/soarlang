const std = @import("std");
const byte_parser = @import("../parser/byte_parser.zig");
const IR_parser = @import("../parser/IR_parser.zig");
const InstructionIterator = IR_parser.InstructionIterator;
const SourceObject = @import("SourceObject.zig");
const FunctionTable = @import("../parser/FunctionTable.zig");
const FunctionGetError = FunctionTable.FunctionGetError;
const instruction = @import("instruction.zig");
const AddressError = instruction.AddressError;
const MemoryError = instruction.MemoryError;
const global = @import("global.zig");
const float = global.float;
const Stack = @import("./Stack.zig");

const InterpretContext = @This();

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
    BreakWhileLoop,
};

const LabelError = error{
    LabelNotFound,
    DuplicateLabel,
    HashMapInternalError,
};

pub const InterpretError = AddressError || MemoryError || ExecutionInterruptionError || InstructionError || ArgumentError || FunctionGetError || LabelError;

const DebugMode = enum { interpret_proc, visual_stack };

source_obj: *SourceObject,
debug_interpret_proc: bool = false,
debug_visual_stack: bool = false,

fn debugPrint(self: InterpretContext, mode: DebugMode, comptime fmt: []const u8, args: anytype) void {
    switch (mode) {
        .interpret_proc => if (!self.debug_interpret_proc) return,
        .visual_stack => if (!self.debug_visual_stack) return,
    }

    std.debug.print(fmt, args);
}

fn unembrace(str: []const u8) []const u8 {
    return str[1 .. str.len - 1];
}

fn resolveSymbol(self: InterpretContext, tape: []const u8, symbol: []const u8) (ArgumentError || instruction.AddressError || LabelError)!usize {
    if (IR_parser.acknowledgeSymbPrefix(symbol, '_')) |pre_symb| {
        switch (byte_parser.squashStrBlock(pre_symb)) {
            // predefined symbols
            byte_parser.squashStrBlock("RTADDR") => return try instruction.getReturnAddress(tape),
            else => {
                // predefined symbols with arguments
                if (std.mem.eql(u8, pre_symb[0..3], "ARG")) {
                    const arg_num = std.fmt.parseUnsigned(usize, pre_symb[3..], 0) catch return ArgumentError.CouldNotParse;
                    return try instruction.getArgAddress(tape, arg_num);
                }
            },
        }
    }

    // user defined labels local to the current stack
    const label = self.source_obj.stack.localLabels.get(symbol) orelse return LabelError.LabelNotFound;
    return label.address;
}

fn resolve(self: InterpretContext, tape: *[]const u8, str: []const u8, is_value_resolution: bool) (ArgumentError || instruction.AddressError || LabelError)!isize {
    var value: isize = undefined;

    if (str[0] == '[' and str[str.len - 1] == ']') {
        const orig_tape = tape.*;

        value = try resolve(self, tape, unembrace(str), is_value_resolution);
        debugPrint(self, .interpret_proc, "\t\tvalue before dereference: {d}\n\r", .{value});
        value = try instruction.wordValue(tape.*, @bitCast(value));
        debugPrint(self, .interpret_proc, "\t\tvalue after dereference: {d}\n\r", .{value});

        tape.* = orig_tape;
        debugPrint(self, .interpret_proc, "\t\toverridden tape with original tape\n\r", .{});
    } else {
        var no_offset = std.mem.splitAny(u8, str, "+-");

        const no_offset_str = no_offset.first();
        const offset_str = no_offset.next();

        if (offset_str == null and no_offset_str[0] != '[') {
            if (is_value_resolution) {
                value = std.fmt.parseInt(isize, no_offset_str, 0) catch |err| blk: {
                    break :blk switch (err) {
                        std.fmt.ParseIntError.Overflow => return ArgumentError.CouldNotParse,
                        std.fmt.ParseIntError.InvalidCharacter => inv_char: {
                            debugPrint(self, .interpret_proc, "\t\treferencing symbol: {s}\n\r", .{no_offset_str});
                            const ptr = global.referenceGlobal(no_offset_str) catch glblref_err: {
                                break :glblref_err global.ScopePtr.nonGlobalPtr(try resolveSymbol(self, tape.*, no_offset_str));
                            };
                            debugPrint(self, .interpret_proc, "\t\tresolved symbol - address: {d}\n\r", .{ptr.address});

                            const ptr_tape: []const u8 = if (ptr.is_global) &global.global_mem else tape.*;

                            break :inv_char try instruction.wordValue(ptr_tape, ptr.address);
                        },
                    };
                };
            } else {
                value = @bitCast(std.fmt.parseUnsigned(usize, no_offset_str, 0) catch |err| blk: {
                    break :blk switch (err) {
                        std.fmt.ParseIntError.Overflow => return ArgumentError.CouldNotParse,
                        std.fmt.ParseIntError.InvalidCharacter => inv_char: {
                            debugPrint(self, .interpret_proc, "\t\treferencing symbol: {s}\n\r", .{no_offset_str});
                            const ptr = global.referenceGlobal(no_offset_str) catch glblref_err: {
                                break :glblref_err global.ScopePtr.nonGlobalPtr(try resolveSymbol(self, tape.*, no_offset_str));
                            };
                            debugPrint(self, .interpret_proc, "\t\tresolved symbol - address: {d}\n\r", .{ptr.address});

                            if (ptr.is_global) {
                                tape.* = &global.global_mem;
                                debugPrint(self, .interpret_proc, "\t\toverridden tape with global tape\n\r", .{});
                            }

                            break :inv_char ptr.address;
                        },
                    };
                });
            }
        } else {
            value = try resolve(self, tape, no_offset_str, is_value_resolution);
            debugPrint(self, .interpret_proc, "\t\tvalue: {d}\n\r", .{value});

            if (offset_str != null) {
                value += std.fmt.parseInt(isize, str[no_offset_str.len..], 0) catch 0;
                debugPrint(self, .interpret_proc, "\t\tvalue shifted by offset: {d}\n\r", .{value});
            }
        }
    }

    debugPrint(self, .interpret_proc, "\t\tresolved value: {d}\n\r", .{value});
    return value;
}

pub fn resolveValue(self: InterpretContext, tape: []const u8, val_str: []const u8) (ArgumentError || instruction.AddressError || LabelError)!isize {
    var tape_cpy = tape;
    return try resolve(self, &tape_cpy, val_str, true);
}
pub fn resolveAddress(self: InterpretContext, tape: *[]const u8, addr_str: []const u8) (ArgumentError || instruction.AddressError || LabelError)!usize {
    const address: usize = @bitCast(try resolve(self, tape, addr_str, false));
    debugPrint(self, .interpret_proc, "\t\tresolved address: {d}\n\r", .{address});
    return address;
}

pub fn resolveFloat(self: InterpretContext, tape: []const u8, float_str: []const u8) (ArgumentError || instruction.AddressError || LabelError)!float {
    if (float_str.len == 0)
        return ArgumentError.CouldNotParse;

    var tape_cpy = tape;
    const flt: float = std.fmt.parseFloat(float, float_str) catch @bitCast(try resolve(self, &tape_cpy, float_str, true));

    debugPrint(self, .interpret_proc, "\t\tresolved float: {d}\n\r", .{flt});

    return flt;
}

pub fn unwrapArgs(arg_iter: *IR_parser.ArgumentIterator, comptime arg_count: usize) InstructionError![arg_count][]const u8 {
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
    const code_block_iter = instr_iter.code_block;
    _ = instr_iter.continueInstructionIterator();

    var open_blocks: usize = 0;

    while (instr_iter.next()) |arg_iter| {
        var arg_iter_mut = arg_iter;
        const instr_name = arg_iter_mut.first() orelse continue;

        const instr = instruction.Instruction.fromString(instr_name) orelse continue;

        if (instruction.Instruction.beginsCodeBlock(instr)) {
            open_blocks += 1;
        } else if (instr == .END) {
            if (open_blocks > 0) {
                open_blocks -= 1;
            } else break;
        }
    }

    if (code_block_iter)
        _ = instr_iter.continueCodeBlockIterator();
}

pub fn interpretCodeBlock(self: InterpretContext, instr_iter: *InstructionIterator) InterpretError!void {
    const code_block_iter = instr_iter.code_block;

    try interpret(self, instr_iter.continueCodeBlockIterator());

    if (!code_block_iter)
        _ = instr_iter.continueInstructionIterator();
}

pub fn interpretIf(self: InterpretContext, condition: bool, instr_iter: *InstructionIterator) InterpretError!void {
    if (condition) {
        try interpretCodeBlock(self, instr_iter);

        const arg_iter = instr_iter.peek() orelse return;
        if (std.mem.eql(u8, arg_iter.peekInstrName() orelse return, @tagName(instruction.Instruction.ELSE)))
            breakCodeBlock(instr_iter);
    } else breakCodeBlock(instr_iter);
}

pub fn callFunc(self: InterpretContext, func_instr_iter: *InstructionIterator) InterpretError!void {
    interpret(self, func_instr_iter) catch |err| switch (err) {
        ExecutionInterruptionError.FunctionReturned => return,
        else => return err,
    };
}

pub fn interpret(self: InterpretContext, instr_iter: *InstructionIterator) InterpretError!void {
    const tape = self.source_obj.stack.stack_tape;

    while (instr_iter.next()) |arg_iter| {
        var arg_iter_mut = arg_iter;
        const instr_name = arg_iter_mut.first() orelse continue;
        const instr = instruction.Instruction.fromString(instr_name) orelse continue;
        debugPrint(self, .interpret_proc, "\n\r<instruction: {s}>\n\r", .{@tagName(instr)});

        if (instruction.Instruction.noArgs(instr)) {
            switch (instr) {
                .INIT => try instruction.initTape(tape),
                .RESRV => try instruction.reserve(tape),
                .LABEL => {
                    const args = try unwrapArgs(&arg_iter_mut, 1);
                    const label_name = args[0];
                    debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n\r", .{label_name});

                    const sp_point = try instruction.wordUnsigned(tape, Stack.SP);

                    if (self.source_obj.stack.localLabels.get(label_name) != null)
                        return LabelError.DuplicateLabel;

                    self.source_obj.stack.localLabels.putNoClobber(label_name, global.ScopePtr.nonGlobalPtr(sp_point)) catch return LabelError.HashMapInternalError;
                    debugPrint(self, .interpret_proc, "\t\tcreated label: {s}; value: {d}\n\r", .{ label_name, sp_point });
                },
                .ELSE => try interpretCodeBlock(self, instr_iter),
                .END, .ENDWHILE => {},
                .CALLRAW => {
                    const args = try unwrapArgs(&arg_iter_mut, 1);
                    const func_name = args[0];
                    debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n\r", .{func_name});

                    var func = try self.source_obj.getFunc(func_name);
                    debugPrint(self, .interpret_proc, "\t\tcalling: {s}\n\r", .{func_name});
                    try callFunc(self, &func);
                },
                .BREAK => breakCodeBlock(instr_iter),
                .BREAKWH => return ExecutionInterruptionError.BreakWhileLoop,
                .BREAKFN => return ExecutionInterruptionError.FunctionReturned,
                .RET => try instruction.@"return"(tape),
                .EXIT => return ExecutionInterruptionError.ExecutionAborted,
                else => unreachable,
            }
        } else if (instruction.Instruction.aArg(instr)) {
            var args = try unwrapArgs(&arg_iter_mut, 1);
            debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n\r", .{args[0]});

            var tape1 = tape;
            const address1 = try resolveAddress(self, &tape1, args[0]);

            switch (instr) {
                .STALLOC => try instruction.stackAlloc(tape1, tape, address1),
                .CAST => try instruction.toInt(tape1, address1),
                .CASTF => try instruction.toFloat(tape1, address1),
                .BOOL => try instruction.toBool(tape1, address1),
                .NOT => try instruction.negateWord(tape1, address1),
                .INC => try instruction.incrementWord(tape1, address1),
                .DEC => try instruction.decrementWord(tape1, address1),
                .INCWS => try instruction.incrementWSize(tape1, address1),
                .DECWS => try instruction.decrementWSize(tape1, address1),
                .DEREF => try instruction.dereferenceWord(tape1, tape, address1),
                else => {
                    if (instruction.Instruction.aaArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        debugPrint(self, .interpret_proc, "\t<arg2: {s}>\n\r", .{args[0]});

                        var tape2 = tape;
                        const address2 = try resolveAddress(self, &tape2, args[0]);

                        switch (instr) {
                            else => {
                                args = try unwrapArgs(&arg_iter_mut, 1);
                                debugPrint(self, .interpret_proc, "\t<arg3: {s}>\n\r", .{args[0]});

                                const value3 = try resolveValue(self, tape, args[0]);

                                switch (instr) {
                                    .BYTECPY => try instruction.copyBytes(tape1, address1, tape2, address2, @intCast(value3)),
                                    else => unreachable,
                                }
                            },
                        }
                    }
                    if (instruction.Instruction.avArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        debugPrint(self, .interpret_proc, "\t<arg2: {s}>\n\r", .{args[0]});

                        const value2 = try resolveValue(self, tape, args[0]);

                        switch (instr) {
                            .SET => try instruction.setWord(tape1, address1, value2),
                            .STLCSZ => try instruction.stackAllocSized(tape1, tape, address1, @intCast(value2)),
                            .AND => try instruction.andWord(tape1, address1, value2),
                            .OR => try instruction.orWord(tape1, address1, value2),
                            .PUTSZ => std.debug.print("{any}\n\r", .{try instruction.wordSized(tape1, address1, @intCast(value2))}),
                            .ADD => try instruction.addWord(tape1, address1, value2),
                            .SUB => try instruction.subtractWord(tape1, address1, value2),
                            .MUL => try instruction.multiplyWord(tape1, address1, value2),
                            .DIV => try instruction.divideWord(tape1, address1, value2),
                            .MOD => try instruction.modWord(tape1, address1, @bitCast(value2)),
                            else => {
                                if (instruction.Instruction.avvArg(instr)) {
                                    args = try unwrapArgs(&arg_iter_mut, 1);
                                    debugPrint(self, .interpret_proc, "\t<arg3: {s}>\n\r", .{args[0]});

                                    const value3 = try resolveValue(self, tape, args[0]);

                                    switch (instr) {
                                        .SETSZ => try instruction.setWordSized(tape1, address1, @intCast(value2), value3),
                                        .EQL => try instruction.equal(tape1, address1, value2, value3),
                                        .SMLR => try instruction.equal(tape1, address1, value2, value3),
                                        .GRTR => try instruction.equal(tape1, address1, value2, value3),
                                        else => unreachable,
                                    }
                                }
                            },
                        }
                    } else if (instruction.Instruction.afArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        debugPrint(self, .interpret_proc, "\t<arg2: {s}>\n\r", .{args[0]});

                        const flt2 = try resolveFloat(self, tape, args[0]);

                        switch (instr) {
                            .SETF => try instruction.setFloat(tape1, address1, flt2),
                            else => unreachable,
                        }
                    }
                },
            }
        } else if (instruction.Instruction.vArg(instr)) {
            var args = try unwrapArgs(&arg_iter_mut, 1);
            debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n\r", .{args[0]});

            var value1 = try resolveValue(self, tape, args[0]);

            switch (instr) {
                .PUT => std.debug.print("{any}\n", .{value1}),
                .RSVSZ => try instruction.reserveSized(tape, @intCast(value1)),
                .PUSH => try instruction.push(tape, value1),
                .POP => try instruction.pop(tape, value1),
                .IF => try interpretIf(self, value1 != 0, instr_iter),
                .WHILE => {
                    while (value1 != 0) : (value1 = try resolveValue(self, tape, args[0])) {
                        var code_block_start = instr_iter.*;
                        interpretCodeBlock(self, &code_block_start) catch |err| switch (err) {
                            ExecutionInterruptionError.BreakWhileLoop => break,
                            else => {},
                        };

                        debugPrint(self, .interpret_proc, "\n\r<while loop condition>\n\r", .{});
                        debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n\r", .{args[0]});
                    }

                    breakCodeBlock(instr_iter);
                },
                .CALL => {
                    try instruction.call(tape, value1);
                    debugPrint(self, .visual_stack, "<function call>\n\r", .{});

                    args = try unwrapArgs(&arg_iter_mut, 1);
                    const func_name = args[0];
                    debugPrint(self, .interpret_proc, "\t<arg2: {s}>\n\r", .{func_name});

                    var func = try self.source_obj.getFunc(func_name);
                    debugPrint(self, .interpret_proc, "\t\tcalling: {s}\n\r", .{func_name});
                    try callFunc(self, &func);
                },
                else => {
                    if (instruction.Instruction.vvArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        debugPrint(self, .interpret_proc, "\t<arg2: {s}>\n\r", .{args[0]});

                        const value2 = try resolveValue(self, tape, args[0]);

                        switch (instr) {
                            .IFEQL => try interpretIf(self, value1 == value2, instr_iter),
                            .IFSMLR => try interpretIf(self, value1 < value2, instr_iter),
                            .IFGRTR => try interpretIf(self, value1 > value2, instr_iter),
                            .PUSHSZ => try instruction.pushSized(tape, @intCast(value1), value2),
                            .TESTEQL => {
                                if (self.source_obj.debug_enabled) {
                                    std.debug.assert(value1 == value2);
                                    debugPrint(self, .interpret_proc, "testeql instruction check passed\n\r\n\r", .{});
                                }
                            },
                            else => unreachable,
                        }
                    }
                },
            }
        } else if (instruction.Instruction.fArg(instr)) {
            const args = try unwrapArgs(&arg_iter_mut, 1);
            debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n\r", .{args[0]});

            const flt1 = try resolveFloat(self, tape, args[0]);

            switch (instr) {
                .PUTF => debugPrint(self, .interpret_proc, "{d}\n\r", .{flt1}),
                else => unreachable,
            }
        }

        visualizeTape(self, tape, 0, 256);
        debugPrint(self, .visual_stack, " <- ", .{});
        var arg_iter_debug = arg_iter;
        while (arg_iter_debug.next()) |arg| {
            debugPrint(self, .visual_stack, "{s} ", .{arg});
        }
        debugPrint(self, .visual_stack, "\n\r", .{});
    }
}

fn visualizeTape(self: InterpretContext, tape: []const u8, start: usize, end: usize) void {
    if (start % global.word_size != 0 or end % global.word_size != 0)
        return;

    const observed_tape = tape[start..end];

    var wsize_index: usize = 0;
    while (wsize_index < global.global_mem.len) : (wsize_index += global.word_size) {
        const value = instruction.wordValue(&global.global_mem, wsize_index) catch return;

        if (value == 0) {
            debugPrint(self, .visual_stack, "[] ", .{});
        } else debugPrint(self, .visual_stack, "{d} ", .{value});
    }

    debugPrint(self, .visual_stack, "\n\r", .{});

    wsize_index = 0;
    while (wsize_index < observed_tape.len) : (wsize_index += global.word_size) {
        const value = instruction.wordValue(tape, wsize_index) catch return;

        if (instruction.wordUnsigned(tape, Stack.SP) catch return == wsize_index) {
            debugPrint(self, .visual_stack, "$>{d} ", .{value});
        } else if (instruction.wordUnsigned(tape, Stack.FP) catch return == wsize_index) {
            debugPrint(self, .visual_stack, "%>{d} ", .{value});
        } else if (value == 0) {
            debugPrint(self, .visual_stack, "[] ", .{});
        } else debugPrint(self, .visual_stack, "{d} ", .{value});
    }
}
