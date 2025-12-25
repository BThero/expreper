const std = @import("std");

const usage =
    \\Usage: ./expreper [options] [expr]
    \\
    \\Options:
    \\ -h, --help: Show this usage information
    \\Expr:
    \\ A single integer which fits in a 128-bit signed type.
    \\
;

fn parse_i128(line: []u8) !i128 {
    const num = try std.fmt.parseInt(i128, line, 10);
    return num;
}

fn parse_expr(line: []u8) !i128 {
    const maybe_plus_pos = std.mem.indexOf(u8, line, "+");
    if (maybe_plus_pos == null) {
        return parse_i128(line);
    }
    const plus_pos = maybe_plus_pos.?;
    const lhs = try parse_expr(line[0..plus_pos]);
    const rhs = try parse_expr(line[plus_pos + 1 .. line.len]);
    return try std.math.add(i128, lhs, rhs);
}

fn stdout_print(comptime fmt: []const u8, args: anytype) !void {
    const stdout = std.fs.File.stdout();
    var buffer: [64]u8 = undefined;
    var stdout_file_writer: std.fs.File.Writer = .{
        .interface = std.fs.File.Writer.initInterface(&buffer),
        .file = stdout,
        .mode = .streaming,
    };
    const stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print(fmt, args);
    try stdout_writer.flush();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);

    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
                try stdout_print("{s}", .{usage});
                return std.process.cleanExit();
            } else {
                const num = parse_expr(arg) catch {
                    std.debug.print("Could not parse expression: '{s}'\n", .{arg});
                    std.process.exit(1);
                };
                try stdout_print("Successfully parsed: {}\n", .{num});
                return std.process.cleanExit();
            }
        }
    }

    std.debug.print("{s}", .{usage});
    std.process.exit(1);
}
