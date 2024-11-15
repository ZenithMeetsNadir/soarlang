pub fn isFlag(flag: []const u8) bool {
    if (flag.len > 1)
        return flag[0] == '-';

    return false;
}

pub fn isFlagUnion(flag: []const u8) bool {
    return isFlag(flag) and flag.len > 2;
}

pub fn getFlag(flag: []const u8) []const u8 {
    if (isFlag(flag))
        return flag[1..];

    return &[_]u8{};
}

pub fn containsFlag(flag: u8, flag_curtain: []const u8) bool {
    return for (flag_curtain) |f| {
        break f == flag;
    } else false;
}
