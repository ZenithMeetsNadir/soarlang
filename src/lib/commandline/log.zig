const std = @import("std");

pub const TextColor = enum(u8) {
    info = 36,
    err = 91,
    warn = 33,
    debug = 90,
};

pub fn logPrint(
    comptime format: []const u8,
    args: anytype,
) void {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    const stderr = std.io.getStdErr().writer();
    stderr.print(format, args) catch return;
}

pub fn printColored(
    comptime color: TextColor,
    comptime format: []const u8,
    args: anytype,
) void {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    const stderr = std.io.getStdErr().writer();
    stderr.print("\x1b[{d}m", .{@intFromEnum(color)}) catch return;
    stderr.print(format, args) catch return;
    stderr.print("\x1b[m", .{}) catch return;
}

pub fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix_color = switch (message_level) {
        .info => TextColor.info,
        .err => TextColor.err,
        .warn => TextColor.warn,
        .debug => TextColor.debug,
    };
    const scope_prefix = "(" ++ @tagName(scope) ++ ")";

    logPrint("[", .{});
    printColored(prefix_color, comptime message_level.asText(), .{});
    logPrint("] {s} ", .{scope_prefix});
    logPrint(format ++ "\n", args);
}
