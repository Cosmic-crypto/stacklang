const std = @import("std");
const compiler = @import("compiler.zig");

pub fn main() !void {
    try compiler.compile();
}
