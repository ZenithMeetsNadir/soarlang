const std = @import("std");

pub fn isFlag(flag: []const u8) bool {
    if (flag.len > 1)
        return flag[0] == '-';

    return false;
}

pub fn isOption(option: []const u8) bool {
    if (option.len > 2)
        return option[0] == '-' and option[1] == '-';

    return false;
}

pub fn isFlagUnion(flag: []const u8) bool {
    return isFlag(flag) and flag.len > 2;
}

pub fn getFlags(flag_curtain: []const u8) []const u8 {
    if (isFlag(flag_curtain))
        return flag_curtain[1..];

    return &[_]u8{};
}

pub fn getSingleFlag(flag: []const u8) u8 {
    if (isFlag(flag) and flag.len == 2)
        return flag[1];

    return 0;
}

pub fn containsFlag(args: []const []const u8, flag: []const u8) bool {
    const is_flag = isFlag(flag);
    const is_option = isOption(flag);

    return for (args) |arg| {
        if (is_flag and curtainContainsFlag(getSingleFlag(flag), arg)) {
            break true;
        } else if (is_option and std.mem.eql(u8, arg, flag)) {
            break true;
        }
    } else false;
}

pub fn curtainContainsFlag(flag: u8, flag_curtain: []const u8) bool {
    return for (getFlags(flag_curtain)) |f| {
        if (f == flag)
            break true;
    } else false;
}
