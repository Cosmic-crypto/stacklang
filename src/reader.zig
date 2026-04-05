const std = @import("std");

pub const Return = struct {
    precomped: bool,
    precomped_data: ?[]const u8,
    lines_array: ?std.ArrayList([]const u8),
    pub fn getProgram(self: Return) [][]const u8 {
        return self.lines_array.?.items;
    }
    pub fn deinit(self: *Return, allocator: std.mem.Allocator) void {
        if (self.lines_array) |*arr| {
            for (arr.items) |line| {
                allocator.free(line);
            }
            arr.deinit(allocator);
        }
        if (self.precomped_data) |data| {
            allocator.free(data);
        }
    }
};

pub fn readlines(filename: []const u8, allocator: std.mem.Allocator) anyerror!std.ArrayList([]const u8) {
    const file: std.fs.File = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    var reader = file.deprecatedReader();
    var line_buf: [4096]u8 = undefined;

    var lines: std.ArrayList([]const u8) = std.ArrayList([]const u8).initCapacity(allocator, 1) catch @panic("OOM");

    while (true) {
        const line = reader.readUntilDelimiter(&line_buf, '\n') catch break;
        if (line.len == 0) continue;
        const line_copy = try allocator.alloc(u8, line.len);
        std.mem.copyForwards(u8, line_copy, line);
        try lines.append(allocator, line_copy);
    }

    return lines;
}

pub fn read(filename: []const u8, allocator: std.mem.Allocator) anyerror!Return {
    const is_stl = filename.len >= 4 and std.mem.eql(u8, filename[filename.len - 4 ..], ".stl");
    const is_stlc = filename.len >= 5 and std.mem.eql(u8, filename[filename.len - 5 ..], ".stlc");
    if (!is_stl and !is_stlc) {
        std.log.err("Please make, the file end in: .stl", .{});
        return error.InvalidFileName;
    }

    const base_name = if (is_stlc)
        filename[0 .. filename.len - 5]
    else
        filename[0 .. filename.len - 4];
    const comp_filename = try std.fmt.allocPrint(allocator, "{s}.stlc", .{base_name});
    defer allocator.free(comp_filename);

    if (std.fs.cwd().openFile(comp_filename, .{})) |comp_file| {
        defer comp_file.close();
        const data = try comp_file.readToEndAlloc(allocator, std.math.maxInt(usize));
        return Return{
            .precomped = true,
            .precomped_data = data,
            .lines_array = null,
        };
    } else |_| {
        const program = try readlines(filename, allocator);
        return Return{
            .precomped = false,
            .precomped_data = null,
            .lines_array = program,
        };
    }
}
