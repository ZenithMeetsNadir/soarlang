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
const ManagedString = IR_parser.ManagedString;

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
    // predefined symbols use '_' prefix
    if (IR_parser.acknowledgeSymbPrefix(symbol, IR_parser.predef_symb_prefix)) |pre_symb| {
        switch (byte_parser.squashStrBlock(pre_symb)) {
            // predefined symbols
            byte_parser.squashStrBlock("rtaddr") => return try instruction.getReturnAddress(tape),
            else => {
                // predefined symbols with arguments
                if (std.mem.eql(u8, pre_symb[0..3], "arg")) {
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

fn resolve(self: InterpretContext, tape: *[]const u8, str: []const u8, is_value_resolution: bool, instr_size: ?u8, init: bool) (ArgumentError || instruction.AddressError || LabelError)!isize {
    var value: isize = undefined;
    const size: ?u8 = if (init) instr_size else null;

    if (str[0] == '[' and str[str.len - 1] == ']') {
        const orig_tape = tape.*;

        value = try resolve(self, tape, unembrace(str), is_value_resolution, instr_size, false);
        debugPrint(self, .interpret_proc, "\t\tvalue before dereference: {d}\n", .{value});
        value = try instruction.word(tape.*, @bitCast(value), size);
        debugPrint(self, .interpret_proc, "\t\tvalue after dereference: {d}\n", .{value});

        tape.* = orig_tape;
        debugPrint(self, .interpret_proc, "\t\toverridden tape with original tape\n", .{});
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
                            debugPrint(self, .interpret_proc, "\t\treferencing symbol: {s}\n", .{no_offset_str});
                            const ptr = global.referenceGlobal(no_offset_str) catch glblref_err: {
                                break :glblref_err global.ScopePtr.nonGlobalPtr(try resolveSymbol(self, tape.*, no_offset_str));
                            };
                            debugPrint(self, .interpret_proc, "\t\tresolved symbol - address: {d}\n", .{ptr.address});

                            const ptr_tape: []const u8 = if (ptr.is_global) &global.global_mem else tape.*;

                            break :inv_char try instruction.word(ptr_tape, ptr.address, size);
                        },
                    };
                };
            } else {
                value = @bitCast(std.fmt.parseUnsigned(usize, no_offset_str, 0) catch |err| blk: {
                    break :blk switch (err) {
                        std.fmt.ParseIntError.Overflow => return ArgumentError.CouldNotParse,
                        std.fmt.ParseIntError.InvalidCharacter => inv_char: {
                            debugPrint(self, .interpret_proc, "\t\treferencing symbol: {s}\n", .{no_offset_str});
                            const ptr = global.referenceGlobal(no_offset_str) catch glblref_err: {
                                break :glblref_err global.ScopePtr.nonGlobalPtr(try resolveSymbol(self, tape.*, no_offset_str));
                            };
                            debugPrint(self, .interpret_proc, "\t\tresolved symbol - address: {d}\n", .{ptr.address});

                            if (ptr.is_global) {
                                tape.* = &global.global_mem;
                                debugPrint(self, .interpret_proc, "\t\toverridden tape with global tape\n", .{});
                            }

                            break :inv_char ptr.address;
                        },
                    };
                });
            }
        } else {
            value = try resolve(self, tape, no_offset_str, is_value_resolution, instr_size, init);
            debugPrint(self, .interpret_proc, "\t\tvalue: {d}\n", .{value});

            if (offset_str != null) {
                value += std.fmt.parseInt(isize, str[no_offset_str.len..], 0) catch 0;
                debugPrint(self, .interpret_proc, "\t\tvalue shifted by offset: {d}\n", .{value});
            }
        }
    }

    debugPrint(self, .interpret_proc, "\t\tresolved value: {d}\n", .{value});
    return value;
}

pub fn resolveValue(self: InterpretContext, tape: []const u8, val_str: []const u8, instr_size: ?u8) (ArgumentError || AddressError || LabelError)!isize {
    var tape_mut = tape;
    return try self.resolve(&tape_mut, val_str, true, instr_size, true);
}

pub fn resolveAddress(self: InterpretContext, tape: *[]const u8, addr_str: []const u8) (ArgumentError || AddressError || LabelError)!usize {
    const address: usize = @bitCast(try self.resolve(tape, addr_str, false, null, true));
    self.debugPrint(.interpret_proc, "\t\tresolved address: {d}\n", .{address});
    return address;
}

pub fn resolveFloat(self: InterpretContext, tape: []const u8, float_str: []const u8) (ArgumentError || AddressError || LabelError)!float {
    if (float_str.len == 0)
        return ArgumentError.CouldNotParse;

    var tape_mut = tape;
    const flt: float = std.fmt.parseFloat(float, float_str) catch @bitCast(try self.resolve(&tape_mut, float_str, true, null, true));

    self.debugPrint(.interpret_proc, "\t\tresolved float: {d}\n", .{flt});

    return flt;
}

pub fn resolveString(self: InterpretContext, tape: []const u8, str: []const u8) (ArgumentError || AddressError || LabelError)!ManagedString {
    var tape_mut = tape;
    const str_addr = self.resolveAddress(&tape_mut, str) catch |err| switch (err) {
        ArgumentError.CouldNotParse, LabelError.LabelNotFound => {
            const res_str = IR_parser.purifyStrLiteral(str, self.source_obj.allocator) catch return ArgumentError.CouldNotParse;
            self.debugPrint(.interpret_proc, "\t\tresolved string: {s}\n", .{res_str.str()});

            return res_str;
        },
        else => return err,
    };

    const sliced_str = try instruction.retrieveString(tape, str_addr);
    self.debugPrint(.interpret_proc, "\t\tretrieved string from memory: {s}\n", .{sliced_str});

    return ManagedString{ .sliced_str = sliced_str };
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
        } else if (instr == .end) {
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
        if (std.mem.eql(u8, arg_iter.peekInstrName() orelse return, @tagName(instruction.Instruction.@"else")))
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
        var instr_split = std.mem.splitScalar(u8, arg_iter_mut.first() orelse continue, IR_parser.byte_size_delim);

        const instr_name = instr_split.first();
        const instr = instruction.Instruction.fromString(instr_name) orelse {
            debugPrint(self, .interpret_proc, "\nUNDEFINED INSTRUCTION {s}\n", .{instr_name});
            continue;
        };
        debugPrint(self, .interpret_proc, "\n<instruction: {s}>\n", .{@tagName(instr)});

        const instr_size: ?u8 = blk: {
            const size_str = instr_split.next() orelse break :blk null;
            break :blk std.fmt.parseUnsigned(u8, size_str, 0) catch null;
        };
        self.debugPrint(.interpret_proc, "<instruction size: {d}>\n", .{instr_size orelse global.word_size});

        if (instruction.Instruction.noArgs(instr)) {
            switch (instr) {
                .init => try instruction.initTape(tape),
                .resrv => try instruction.reserve(tape),
                .label => {
                    const args = try unwrapArgs(&arg_iter_mut, 1);
                    const label_name = args[0];
                    debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n", .{label_name});

                    const sp_point = try instruction.wordUnsigned(tape, Stack.SP);

                    if (self.source_obj.stack.localLabels.get(label_name) != null)
                        return LabelError.DuplicateLabel;

                    self.source_obj.stack.localLabels.putNoClobber(label_name, global.ScopePtr.nonGlobalPtr(sp_point)) catch return LabelError.HashMapInternalError;
                    debugPrint(self, .interpret_proc, "\t\tcreated label: {s}; value: {d}\n", .{ label_name, sp_point });
                },
                .@"else" => try interpretCodeBlock(self, instr_iter),
                .end, .endwhile => {},
                .@"break" => breakCodeBlock(instr_iter),
                .breakwh => return ExecutionInterruptionError.BreakWhileLoop,
                .breakfn => return ExecutionInterruptionError.FunctionReturned,
                .ret => try instruction.@"return"(tape),
                .exit => return ExecutionInterruptionError.ExecutionAborted,
                else => unreachable,
            }
        } else if (instruction.Instruction.aArg(instr)) {
            var args = try unwrapArgs(&arg_iter_mut, 1);
            debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n", .{args[0]});

            var tape1 = tape;
            const address1 = try resolveAddress(self, &tape1, args[0]);

            switch (instr) {
                .stlc => try instruction.stackAlloc(tape1, tape, address1),
                .cast => try instruction.toInt(tape1, address1),
                .castf => try instruction.toFloat(tape1, address1),
                .bool => try instruction.toBool(tape1, address1, instr_size),
                .not => try instruction.negateWord(tape1, address1, instr_size),
                .inc => try instruction.incrementWord(tape1, address1, instr_size),
                .dec => try instruction.decrementWord(tape1, address1, instr_size),
                .incws => try instruction.incrementWSize(tape1, address1, instr_size),
                .decws => try instruction.decrementWSize(tape1, address1, instr_size),
                .deref => try instruction.dereferenceWord(tape1, tape, address1),
                else => {
                    if (instruction.Instruction.aaArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        debugPrint(self, .interpret_proc, "\t<arg2: {s}>\n", .{args[0]});

                        var tape2 = tape;
                        const address2 = try resolveAddress(self, &tape2, args[0]);

                        switch (instr) {
                            else => {
                                args = try unwrapArgs(&arg_iter_mut, 1);
                                debugPrint(self, .interpret_proc, "\t<arg3: {s}>\n", .{args[0]});

                                const value3 = try resolveValue(self, tape, args[0], instr_size);

                                switch (instr) {
                                    .bytecpy => try instruction.copyBytes(tape1, address1, tape2, address2, @bitCast(value3)),
                                    else => unreachable,
                                }
                            },
                        }
                    }
                    if (instruction.Instruction.avArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        debugPrint(self, .interpret_proc, "\t<arg2: {s}>\n", .{args[0]});

                        const value2 = try resolveValue(self, tape, args[0], instr_size);

                        switch (instr) {
                            .set => try instruction.set(tape1, address1, value2, instr_size),
                            .stlcsz => try instruction.stackAllocSized(tape1, tape, address1, @bitCast(value2)),
                            .@"and" => try instruction.andWord(tape1, address1, value2, instr_size),
                            .@"or" => try instruction.orWord(tape1, address1, value2, instr_size),
                            .putsz => std.debug.print("{any}\n", .{try instruction.wordSized(tape1, address1, @intCast(value2))}),
                            .add => try instruction.addWord(tape1, address1, value2, instr_size),
                            .sub => try instruction.subtractWord(tape1, address1, value2, instr_size),
                            .mul => try instruction.multiplyWord(tape1, address1, value2, instr_size),
                            .div => try instruction.divideWord(tape1, address1, value2, instr_size),
                            .mod => try instruction.modWord(tape1, address1, @bitCast(value2), instr_size),
                            else => {
                                if (instruction.Instruction.avvArg(instr)) {
                                    args = try unwrapArgs(&arg_iter_mut, 1);
                                    debugPrint(self, .interpret_proc, "\t<arg3: {s}>\n", .{args[0]});

                                    const value3 = try resolveValue(self, tape, args[0], instr_size);

                                    switch (instr) {
                                        .setsz => try instruction.setSized(tape1, address1, value3, @intCast(value2)),
                                        else => unreachable,
                                    }
                                }
                            },
                        }
                    } else if (instruction.Instruction.afArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        debugPrint(self, .interpret_proc, "\t<arg2: {s}>\n", .{args[0]});

                        const flt2: float = try resolveFloat(self, tape, args[0]);

                        switch (instr) {
                            .setf => try instruction.setFloat(tape1, address1, flt2),
                            else => unreachable,
                        }
                    } else if (instruction.Instruction.asArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        self.debugPrint(.interpret_proc, "\t<arg2: {s}>\n", .{args[0]});

                        const res_str2 = try self.resolveString(tape1, args[0]);
                        defer res_str2.dispose();

                        const string2 = res_str2.str();

                        switch (instr) {
                            .storestr => try instruction.storeString(tape, address1, string2),
                            else => unreachable,
                        }
                    }
                },
            }
        } else if (instruction.Instruction.vArg(instr)) {
            var args = try unwrapArgs(&arg_iter_mut, 1);
            debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n", .{args[0]});

            var value1 = try resolveValue(self, tape, args[0], instr_size);

            switch (instr) {
                .put => std.debug.print("{any}\n", .{value1}),
                .putx => std.debug.print("{x}\n", .{value1}),
                .rsvsz => try instruction.reserveSized(tape, @intCast(value1)),
                .push => try instruction.push(tape, value1, instr_size),
                .pop => try instruction.pop(tape, value1),
                .@"if" => try interpretIf(self, value1 != 0, instr_iter),
                .@"while" => {
                    while (value1 != 0) : (value1 = try resolveValue(self, tape, args[0], instr_size)) {
                        var code_block_start = instr_iter.*;
                        interpretCodeBlock(self, &code_block_start) catch |err| switch (err) {
                            ExecutionInterruptionError.BreakWhileLoop => break,
                            else => {},
                        };

                        debugPrint(self, .interpret_proc, "\n<while loop condition>\n", .{});
                        debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n", .{args[0]});
                    }

                    breakCodeBlock(instr_iter);
                },
                else => {
                    if (instruction.Instruction.vvArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        debugPrint(self, .interpret_proc, "\t<arg2: {s}>\n", .{args[0]});

                        const value2 = try resolveValue(self, tape, args[0], instr_size);

                        switch (instr) {
                            .ifeql => try self.interpretIf(value1 == value2, instr_iter),
                            .ifnoeq => try self.interpretIf(value1 != value2, instr_iter),
                            .ifsmlr => try self.interpretIf(value1 < value2, instr_iter),
                            .ifsmeq => try self.interpretIf(value1 <= value2, instr_iter),
                            .ifgrtr => try self.interpretIf(value1 > value2, instr_iter),
                            .ifgreq => try self.interpretIf(value1 >= value2, instr_iter),
                            .pushsz => try instruction.pushSized(tape, value2, @intCast(value1)),
                            .eql => try instruction.equal(tape, value1, value1, instr_size),
                            .noeq => try instruction.notEqual(tape, value1, value1, instr_size),
                            .smlr => try instruction.smaller(tape, value1, value1, instr_size),
                            .smeq => try instruction.smallerOrEqual(tape, value1, value1, instr_size),
                            .grtr => try instruction.greater(tape, value1, value1, instr_size),
                            .greq => try instruction.greaterOrEqual(tape, value1, value1, instr_size),
                            .testeql => {
                                if (self.source_obj.debug_enabled) {
                                    std.debug.assert(value1 == value2);
                                    debugPrint(self, .interpret_proc, "testeql instruction check passed\n\n", .{});
                                }
                            },
                            else => unreachable,
                        }
                    } else if (instruction.Instruction.vsArg(instr)) {
                        args = try unwrapArgs(&arg_iter_mut, 1);
                        debugPrint(self, .interpret_proc, "\t<arg2: {s}>\n", .{args[0]});

                        const res_str2 = try self.resolveString(tape, args[0]);
                        defer res_str2.dispose();

                        const string2 = res_str2.str();

                        switch (instr) {
                            .call => {
                                try instruction.call(tape, value1);
                                debugPrint(self, .visual_stack, "<function call>\n", .{});

                                var func = try self.source_obj.getFunc(string2);
                                debugPrint(self, .interpret_proc, "\t\tcalling: {s}\n", .{string2});
                                try callFunc(self, &func);
                            },
                            else => unreachable,
                        }
                    }
                },
            }
        } else if (instruction.Instruction.fArg(instr)) {
            const args = try unwrapArgs(&arg_iter_mut, 1);
            debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n", .{args[0]});

            const flt1 = try self.resolveFloat(tape, args[0]);

            switch (instr) {
                .putf => debugPrint(self, .interpret_proc, "{d}\n", .{flt1}),
                else => unreachable,
            }
        } else if (instruction.Instruction.sArg(instr)) {
            const args = try unwrapArgs(&arg_iter_mut, 1);
            debugPrint(self, .interpret_proc, "\t<arg1: {s}>\n", .{args[0]});

            const res_str1 = try self.resolveString(tape, args[0]);
            defer res_str1.dispose();

            const string1 = res_str1.str();

            switch (instr) {
                .callraw => {
                    var func = try self.source_obj.getFunc(string1);
                    debugPrint(self, .interpret_proc, "\t\tcalling: {s}\n", .{string1});
                    try callFunc(self, &func);
                },
                .pushstr => try instruction.pushString(tape, string1),
                else => unreachable,
            }
        }

        visualizeTape(self, tape, 0, 256);
        debugPrint(self, .visual_stack, " <- ", .{});
        var arg_iter_debug = arg_iter;
        while (arg_iter_debug.next()) |arg| {
            debugPrint(self, .visual_stack, "{s} ", .{arg});
        }
        debugPrint(self, .visual_stack, "\n", .{});
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
        } else debugPrint(self, .visual_stack, "{x} ", .{value});
    }

    debugPrint(self, .visual_stack, "\n", .{});

    wsize_index = 0;
    while (wsize_index < observed_tape.len) : (wsize_index += global.word_size) {
        const value = instruction.wordValue(tape, wsize_index) catch return;

        if (instruction.wordUnsigned(tape, Stack.SP) catch return == wsize_index) {
            debugPrint(self, .visual_stack, "$>{x} ", .{value});
        } else if (instruction.wordUnsigned(tape, Stack.FP) catch return == wsize_index) {
            debugPrint(self, .visual_stack, "%>{x} ", .{value});
        } else if (value == 0) {
            debugPrint(self, .visual_stack, "[] ", .{});
        } else debugPrint(self, .visual_stack, "{x} ", .{value});
    }
}
