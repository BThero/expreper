const std = @import("std");

pub fn is_one_of(options: []const u8, ch: u8) bool {
    return std.mem.containsAtLeastScalar(u8, options, 1, ch);
}
