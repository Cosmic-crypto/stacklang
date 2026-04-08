const std = @import("std");
const vm = @import("vm.zig");
const reader = @import("reader.zig");
const writer = @import("writer.zig");
const parser = @import("parser.zig");

pub fn compile(filename: []const u8, gpa: std.mem.Allocator) !void {
    var reader_ret: reader.Return = try reader.read(filename, gpa);

    if (reader_ret.precomped) {
        const program = try deserialize(reader_ret.precomped_data.?, gpa);
        var vm_instance: vm.VM = vm.VM.init(gpa);
        vm_instance.run(program);
        reader_ret.deinit(gpa);
        return;
    }

    const lines = reader_ret.getProgram();

    defer reader_ret.deinit(gpa);

    var compiled_program: std.ArrayList(u8) = try std.ArrayList(u8).initCapacity(gpa, 0);
    var error_lines: std.ArrayList(usize) = try std.ArrayList(usize).initCapacity(gpa, 0);

    defer compiled_program.deinit(gpa);
    defer error_lines.deinit(gpa);

    // parse line by line
    for (lines, 0..) |line, line_idx_| {
        const line_idx: usize = line_idx_ + 1;

        const parsed: ?parser.ParsedLine = try parser.parseLine(line);
        const parsed_line: parser.ParsedLine = parsed orelse continue;
        const cmd: []const u8 = parsed_line.cmd;
        const val: ?[]const u8 = parsed_line.val;

        if (std.mem.eql(u8, cmd, "EnabDefPop")) {
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.EnabDefPop));
        } else if (std.mem.eql(u8, cmd, "Push")) {
            const vstr: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const v: i32 = std.fmt.parseInt(i32, vstr, 10) catch {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.Push));
            try writeInt(&compiled_program, v, gpa);
        } else if (std.mem.eql(u8, cmd, "Add")) {
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.Add));
        } else if (std.mem.eql(u8, cmd, "Sub")) {
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.Sub));
        } else if (std.mem.eql(u8, cmd, "Mul")) {
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.Mul));
        } else if (std.mem.eql(u8, cmd, "Div")) {
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.Div));
        } else if (std.mem.eql(u8, cmd, "Pow")) {
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.Pow));
        } else if (std.mem.eql(u8, cmd, "Print")) {
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.Print));
        } else if (std.mem.eql(u8, cmd, "PrintAll")) {
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.PrintAll));
        } else if (std.mem.eql(u8, cmd, "PrintIdx")) {
            const vstr: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const v: usize = std.fmt.parseUnsigned(usize, vstr, 10) catch {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.PrintIdx));
            try writeInt(&compiled_program, v, gpa);
        } else if (std.mem.eql(u8, cmd, "Dup")) {
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.Dup));
        } else if (std.mem.eql(u8, cmd, "Pop")) {
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.Pop));
        } else if (std.mem.eql(u8, cmd, "PopIdx")) {
            const target: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const idx: usize = std.fmt.parseInt(usize, target, 10) catch {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.PopIdx));
            try writeInt(&compiled_program, idx, gpa);
        } else if (std.mem.eql(u8, cmd, "Jmp")) {
            const target: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const idx: usize = std.fmt.parseInt(usize, target, 10) catch {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.Jmp));
            try writeInt(&compiled_program, idx, gpa);
        } else if (std.mem.eql(u8, cmd, "JmpIfZ")) {
            const target: []const u8 = val orelse {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            const idx: usize = std.fmt.parseInt(usize, target, 10) catch {
                try error_lines.append(gpa, line_idx);
                continue;
            };
            try compiled_program.append(gpa, @intFromEnum(vm.Instr.JmpIfZ));
            try writeInt(&compiled_program, idx, gpa);
        } else {
            try error_lines.append(gpa, line_idx);
        }
    }

    if (error_lines.items.len != 0) {
        for (error_lines.items) |line| std.log.err("Error at line: {}", .{line});
        return error.InvalidSyntax;
    }

    try writer.writeCompiled(filename, compiled_program.items, gpa);
}

fn writeInt(list: *std.ArrayList(u8), value: anytype, gpa: std.mem.Allocator) !void {
    const T = @TypeOf(value);
    switch (T) {
        i32 => {
            var v = value;
            const bytes = std.mem.asBytes(&v);
            try list.appendSlice(gpa, bytes);
        },
        usize => {
            var v = value;
            const bytes = std.mem.asBytes(&v);
            try list.appendSlice(gpa, bytes);
        },
        else => @compileError("unsupported type"),
    }
}

fn deserialize(data: []const u8, gpa: std.mem.Allocator) ![]vm.Instr {
    var program = std.ArrayList(vm.Instr).initCapacity(gpa, 0) catch @panic("OOM");
    var i: usize = 0;
    while (i < data.len) {
        const tag = data[i];
        i += 1;
        switch (tag) {
            0 => try program.append(gpa, .Add),
            1 => try program.append(gpa, .Sub),
            2 => try program.append(gpa, .Mul),
            3 => try program.append(gpa, .Div),
            4 => try program.append(gpa, .Pow),
            5 => try program.append(gpa, .Print),
            6 => {
                var buf: [8]u8 = undefined;
                @memcpy(buf[0..], data[i..][0..8]);
                const v = std.mem.readInt(usize, &buf, .little);
                i += 8;
                try program.append(gpa, .{ .PrintIdx = v });
            },
            7 => try program.append(gpa, .PrintAll),
            8 => try program.append(gpa, .Dup),
            9 => try program.append(gpa, .Pop),
            10 => {
                var buf: [8]u8 = undefined;
                @memcpy(buf[0..], data[i..][0..8]);
                const v = std.mem.readInt(usize, &buf, .little);
                i += 8;
                try program.append(gpa, .{ .PopIdx = v });
            },
            11 => {
                var buf: [4]u8 = undefined;
                @memcpy(buf[0..], data[i..][0..4]);
                const v = std.mem.readInt(i32, &buf, .little);
                i += 4;
                try program.append(gpa, .{ .Push = v });
            },
            12 => {
                var buf: [8]u8 = undefined;
                @memcpy(buf[0..], data[i..][0..8]);
                const v = std.mem.readInt(usize, &buf, .little);
                i += 8;
                try program.append(gpa, .{ .Jmp = v });
            },
            13 => {
                var buf: [8]u8 = undefined;
                @memcpy(buf[0..], data[i..][0..8]);
                const v = std.mem.readInt(usize, &buf, .little);
                i += 8;
                try program.append(gpa, .{ .JmpIfZ = v });
            },
            14 => try program.append(gpa, .EnabDefPop),
            else => return error.InvalidInstruction,
        }
    }
    return program.items;
}
