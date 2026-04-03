const compiler = @import("compiler.zig");
const reader = @import("reader.zig");
const std = @import("std");

pub fn main() !void {
    // retrieve command line args (filename)
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = general_purpose_allocator.deinit();

    const gpa: std.mem.Allocator = general_purpose_allocator.allocator();

    const args: [][:0]u8 = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    const lines: [][]const u8 = try reader.read(args[1]);
    try compiler.compile(lines, gpa);
}
