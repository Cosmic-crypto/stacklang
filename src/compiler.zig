const std = @import("std");
const reader = @import("reader.zig");
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

pub fn compile() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = general_purpose_allocator.deinit();

    const gpa: std.mem.Allocator = general_purpose_allocator.allocator();

    const args: [][:0]u8 = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    const lines: [][]const u8 = try reader.read(args[1]);
    var compiled_program: std.ArrayList(vm.Instr) = try std.ArrayList(vm.Instr).initCapacity(gpa, 1);

    for (lines) |line| {
        const parsed = try parseLine(line);
        const parsed_line = parsed orelse continue;
        const cmd = parsed_line.cmd;
        const val = parsed_line.val;

        if (std.mem.eql(u8, cmd, "Push")) {
            const vstr = val orelse return error.InvalidSyntax;
            const v = std.fmt.parseInt(i32, vstr, 10) catch return error.InvalidNumber;
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
