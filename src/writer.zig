const std = @import("std");

pub fn writeCompiled(filename_: []const u8, compedprog: []const u8, allocator: std.mem.Allocator) !void {
    const base_name = if (filename_.len >= 4 and std.mem.eql(u8, filename_[filename_.len - 4 ..], ".stl"))
        filename_[0 .. filename_.len - 4]
    else if (filename_.len >= 5 and std.mem.eql(u8, filename_[filename_.len - 5 ..], ".stlc"))
        filename_[0 .. filename_.len - 5]
    else
        filename_;
    const filename = try std.fmt.allocPrint(allocator, "{s}.stlc", .{base_name});
    defer allocator.free(filename);

    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    try file.writeAll(compedprog);
}
