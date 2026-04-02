const std = @import("std");

pub fn read(filename: []const u8) ![][]const u8 {
    const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    var reader = file.deprecatedReader();
    var line_buf: [4096]u8 = undefined;

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator: std.mem.Allocator = gpa.allocator();

    var lines: std.ArrayList([]const u8) = try std.ArrayList([]const u8).initCapacity(allocator, 1);

    while (true) {
        const line = reader.readUntilDelimiter(&line_buf, '\n') catch break;
        if (line.len == 0) break;
        const line_copy = try allocator.alloc(u8, line.len);
        std.mem.copyForwards(u8, line_copy, line);
        try lines.append(allocator, line_copy);
    }

    return lines.items;
}
