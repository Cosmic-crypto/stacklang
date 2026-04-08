const compiler = @import("compiler.zig");
const std = @import("std");

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = general_purpose_allocator.deinit();

    const gpa: std.mem.Allocator = general_purpose_allocator.allocator();

    const args: [][:0]u8 = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    try compiler.compile(args[1], gpa);
}
