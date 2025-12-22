const std = @import("std");

const usage =
    \\Usage: ./expreper [options]
    \\
    \\Options:
    \\ -h, --help: Show this usage information
    \\
;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);

    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
                try std.fs.File.stdout().writeAll(usage);
                return std.process.cleanExit();
            } else {
                std.debug.print("Unrecognized command-line argument: '{s}'", .{arg});
                std.process.exit(1);
            }
        }
    }

    std.debug.print("Hello from expreper!\n", .{});
}
