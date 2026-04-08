const std = @import("std");

pub const ParsedLine = struct {
    cmd: []const u8,
    val: ?[]const u8,
};

pub fn parseLine(line: []const u8) !?ParsedLine {
    const comment_idx: usize = std.mem.indexOf(u8, line, "#") orelse line.len;
    const clean_line: []const u8 = line[0..comment_idx];
    const trimmed: []const u8 = std.mem.trim(u8, clean_line, " \t");

    if (trimmed.len == 0) return null; // empty or comment line

    const parts = std.mem.splitScalar(u8, trimmed, ',');
    var it = parts;

    const cmd: []const u8 = it.next() orelse return error.InvalidSyntax;
    const val: ?[]const u8 = it.next();

    const cmd_trimmed: []const u8 = std.mem.trim(u8, cmd, " \t");
    const val_trimmed: ?[]const u8 = if (val) |v| std.mem.trim(u8, v, " \t") else null;

    return ParsedLine{
        .cmd = cmd_trimmed,
        .val = val_trimmed,
    };
}
