const std = @import("std");
const vm = @import("vm.zig");

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

    const cmd = it.next() orelse return error.InvalidSyntax;
    const val = it.next();

    const cmd_trimmed: []const u8 = std.mem.trim(u8, cmd, " \t");
    const val_trimmed: ?[]const u8 = if (val) |v| std.mem.trim(u8, v, " \t") else null;

    return ParsedLine{
        .cmd = cmd_trimmed,
        .val = val_trimmed,
    };
}

pub fn compile(lines: [][]const u8, gpa: std.mem.Allocator) !void {
    var compiled_program: std.ArrayList(vm.Instr) = try std.ArrayList(vm.Instr).initCapacity(gpa, 1);

    // parse line by line
    for (lines) |line| {
        const parsed: ?ParsedLine = try parseLine(line);
        const parsed_line: ParsedLine = parsed orelse continue;
        const cmd: []const u8 = parsed_line.cmd;
        const val: ?[]const u8 = parsed_line.val;

        if (std.mem.eql(u8, cmd, "Push")) {
            const vstr: []const u8 = val orelse return error.InvalidSyntax;
            const v: i32 = std.fmt.parseInt(i32, vstr, 10) catch return error.InvalidNumber;
            try compiled_program.append(gpa, .{ .Push = v });
        } else if (std.mem.eql(u8, cmd, "Add")) {
            try compiled_program.append(gpa, .Add);
        } else if (std.mem.eql(u8, cmd, "Sub")) {
            try compiled_program.append(gpa, .Sub);
        } else if (std.mem.eql(u8, cmd, "Mul")) {
            try compiled_program.append(gpa, .Mul);
        } else if (std.mem.eql(u8, cmd, "Print")) {
            try compiled_program.append(gpa, .Print);
        } else if (std.mem.eql(u8, cmd, "Dup")) {
            try compiled_program.append(gpa, .Dup);
        } else if (std.mem.eql(u8, cmd, "Pop")) {
            try compiled_program.append(gpa, .Pop);
        } else if (std.mem.eql(u8, cmd, "Jmp")) {
            const target: []const u8 = val orelse return error.InvalidSyntax;
            const idx: usize = std.fmt.parseInt(usize, target, 10) catch return error.InvalidNumber;
            try compiled_program.append(gpa, .{ .Jmp = idx });
        } else if (std.mem.eql(u8, cmd, "JmpIfZ")) {
            const target: []const u8 = val orelse return error.InvalidSyntax;
            const idx: usize = std.fmt.parseInt(usize, target, 10) catch return error.InvalidNumber;
            try compiled_program.append(gpa, .{ .JmpIfZ = idx });
        } else {
            return error.UnknownCmd;
        }
    }

    var vm_instance: vm.VM = .{};
    vm_instance.run(compiled_program.items);
}
