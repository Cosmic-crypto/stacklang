const std = @import("std");

pub fn read(filename: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    if (!std.mem.eql(u8, filename[filename.len - 4 ..], ".stl")) {
        std.log.err("Please make, the file end in: .stl", .{});
        return error.InvalidFileName;
    }

    const file: std.fs.File = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    var reader = file.deprecatedReader();
    var line_buf: [4096]u8 = undefined;

    var lines: std.ArrayList([]const u8) = try std.ArrayList([]const u8).initCapacity(allocator, 1);

    while (true) {
        const line = reader.readUntilDelimiter(&line_buf, '\n') catch break;
        if (line.len == 0) continue;
        const line_copy = try allocator.alloc(u8, line.len);
        std.mem.copyForwards(u8, line_copy, line);
        try lines.append(allocator, line_copy);
    }

    return lines.items;
}

pub fn freeLines(lines: [][]const u8, allocator: std.mem.Allocator) void {
    for (lines) |line| {
        allocator.free(line);
    }
}
