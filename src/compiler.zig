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

    const cmd: []const u8 = it.next() orelse return error.InvalidSyntax;
    const val: ?[]const u8 = it.next();

    const cmd_trimmed: []const u8 = std.mem.trim(u8, cmd, " \t");
    const val_trimmed: ?[]const u8 = if (val) |v| std.mem.trim(u8, v, " \t") else null;

    return ParsedLine{
        .cmd = cmd_trimmed,
        .val = val_trimmed,
    };
}

pub fn compile(lines: [][]const u8, gpa: std.mem.Allocator) !void {
    var compiled_program: std.ArrayList(vm.Instr) = try std.ArrayList(vm.Instr).initCapacity(gpa, 0);
    var error_lines: std.ArrayList(usize) = try std.ArrayList(usize).initCapacity(gpa, 0);

    defer compiled_program.deinit(gpa);
    defer error_lines.deinit(gpa);

    var vm_instance: vm.VM = vm.VM.init(gpa);

    // parse line by line
    for (lines, 0..) |line, line_idx_| {
        const line_idx: usize = line_idx_ + 1;

        const parsed: ?ParsedLine = try parseLine(line);
        const parsed_line: ParsedLine = parsed orelse continue;
        const cmd: []const u8 = parsed_line.cmd;
        const val: ?[]const u8 = parsed_line.val;

        if (std.mem.eql(u8, cmd, "EnabDefPop")) {
            const bstr: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const b: bool = if (std.mem.eql(u8, bstr, "true"))
                true
            else if (std.mem.eql(u8, bstr, "false"))
                false
            else {
                try error_lines.append(gpa, line_idx);
                continue;
            };

            vm_instance.enab_def_pop(b);
        } else if (std.mem.eql(u8, cmd, "Push")) {
            const vstr: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const v: i32 = std.fmt.parseInt(i32, vstr, 10) catch {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            try compiled_program.append(gpa, .{ .Push = v });
        } else if (std.mem.eql(u8, cmd, "Add")) {
            try compiled_program.append(gpa, .Add);
        } else if (std.mem.eql(u8, cmd, "Sub")) {
            try compiled_program.append(gpa, .Sub);
        } else if (std.mem.eql(u8, cmd, "Mul")) {
            try compiled_program.append(gpa, .Mul);
        } else if (std.mem.eql(u8, cmd, "Div")) {
            try compiled_program.append(gpa, .Div);
        } else if (std.mem.eql(u8, cmd, "Pow")) {
            try compiled_program.append(gpa, .Pow);
        } else if (std.mem.eql(u8, cmd, "Print")) {
            try compiled_program.append(gpa, .Print);
        } else if (std.mem.eql(u8, cmd, "PrintAll")) {
            try compiled_program.append(gpa, .PrintAll);
        } else if (std.mem.eql(u8, cmd, "PrintIdx")) {
            const vstr: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const v: usize = std.fmt.parseUnsigned(usize, vstr, 10) catch {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            try compiled_program.append(gpa, .{ .PrintIdx = v });
        } else if (std.mem.eql(u8, cmd, "Dup")) {
            try compiled_program.append(gpa, .Dup);
        } else if (std.mem.eql(u8, cmd, "Pop")) {
            try compiled_program.append(gpa, .Pop);
        } else if (std.mem.eql(u8, cmd, "PopIdx")) {
            const target: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const idx: usize = std.fmt.parseInt(usize, target, 10) catch {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            try compiled_program.append(gpa, .{ .PopIdx = idx });
        } else if (std.mem.eql(u8, cmd, "Jmp")) {
            const target: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const idx: usize = std.fmt.parseInt(usize, target, 10) catch {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            try compiled_program.append(gpa, .{ .Jmp = idx });
        } else if (std.mem.eql(u8, cmd, "JmpIfZ")) {
            const target: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const idx: usize = std.fmt.parseInt(usize, target, 10) catch {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            try compiled_program.append(gpa, .{ .JmpIfZ = idx });
        } else {
            try error_lines.append(gpa, line_idx);
        }
    }

    if (error_lines.items.len != 0) {
        for (error_lines.items) |line| std.log.err("Error at line: {}", .{line});
        return error.InvalidSyntax;
    }

    vm_instance.run(compiled_program.items);
}
