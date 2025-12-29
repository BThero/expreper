const std = @import("std");

const usage =
    \\Usage: ./expreper [options] [expr]
    \\
    \\Options:
    \\ -h, --help: Show this usage information
    \\Expr:
    \\ A simple mathematical expression which consists of integer numbers and '+', '-', '*' operators.
    \\ Positive integers cannot have a '+' sign in front of them. 
    \\ Negative integers have to be surrounded by round braces, e.g. (-5)*(-3).
    \\ Round braces are not supported in all other cases. 
    \\ Good Examples: "2", "(-3)", "1+2-4", "13*37-45*15*2" "7*6-3*4*9+12-6".
    \\ Bad Examples: "3*(4+5)", "+2", "-3". 
;

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

const DIGITS = "0123456789";
const FIRST_ORDER_OP = "+-";
const SECOND_ORDER_OP = "*";

fn parse_i128(line: []u8) !i128 {
    const n = line.len;
    if (n > 2 and line[0] == '(' and line[n - 1] == ')') {
        return parse_i128(line[1 .. n - 1]);
    } else {
        return try std.fmt.parseInt(i128, line, 10);
    }
}

const ParseError = error{
    UnrecognizedOperator,
};

const Simplification = struct { prefix: []u8, suffix: []u8, value: i128 };

fn is_one_of(options: []const u8, ch: u8) bool {
    return std.mem.containsAtLeastScalar(u8, options, 1, ch);
}

fn compute(lhs: i128, rhs: i128, op: u8) !i128 {
    return switch (op) {
        '+' => std.math.add(i128, lhs, rhs),
        '-' => std.math.sub(i128, lhs, rhs),
        '*' => std.math.mul(i128, lhs, rhs),
        else => ParseError.UnrecognizedOperator,
    };
}

fn extract_num_from_begin(line: []u8) ?struct { []u8, i128 } {
    const n = line.len;
    if (n == 0) {
        return null;
    }
    var pos: usize = undefined;
    if (line[0] == '(') {
        pos = std.mem.indexOfScalar(u8, line, ')') orelse {
            return null;
        };
        pos += 1;
    } else {
        const tmp = std.mem.indexOfNone(u8, line, DIGITS);
        pos = if (tmp == null) n else tmp.?;
    }
    const prefix = line[0..pos];
    const suffix = line[pos..n];
    const num = parse_i128(prefix) catch {
        return null;
    };
    return .{ suffix, num };
}

fn extract_num_from_end(line: []u8) ?struct { []u8, i128 } {
    const n = line.len;
    if (n == 0) {
        return null;
    }
    var pos: usize = undefined;
    if (line[n - 1] == ')') {
        pos = std.mem.lastIndexOfScalar(u8, line, '(') orelse {
            return null;
        };
    } else {
        const tmp = std.mem.lastIndexOfNone(u8, line, DIGITS);
        pos = if (tmp == null) 0 else tmp.? + 1;
    }
    const prefix = line[0..pos];
    const suffix = line[pos..n];
    const num = parse_i128(suffix) catch {
        return null;
    };
    return .{ prefix, num };
}

fn find_simplification(ops: []const u8, line: []u8) ?Simplification {
    // [...](op)[...]
    for (line, 0..line.len) |ch, i| {
        if (!is_one_of(ops, ch)) {
            continue;
        }
        if (ch == '-' and i > 0 and line[i - 1] == '(') {
            continue;
        }

        const lhs = extract_num_from_end(line[0..i]) orelse {
            return null;
        };
        const rhs = extract_num_from_begin(line[i + 1 .. line.len]) orelse {
            return null;
        };
        const result = compute(lhs.@"1", rhs.@"1", ch) catch {
            return null;
        };
        return Simplification{ .prefix = lhs.@"0", .suffix = rhs.@"0", .value = result };
    }
    return null;
}

fn append_num(line: *std.array_list.Aligned(u8, null), num: i128) !void {
    const allocator = std.heap.page_allocator;
    if (num == 0) {
        try line.append(allocator, '0');
        return;
    }
    if (num < 0) {
        try line.appendSlice(allocator, "(-");
        const positive_num = try std.math.negate(num);
        try append_num(line, positive_num);
        try line.append(allocator, ')');
        return;
    }
    const range_start = line.items.len;
    var vnum = num;
    while (vnum > 0) {
        const last_digit = @mod(vnum, 10);
        const d: u8 = @intCast('0' + last_digit);
        try line.append(allocator, d);
        vnum = @divTrunc(vnum, 10);
    }
    const range_end = line.items.len;
    std.mem.reverse(u8, line.items[range_start..range_end]);
}

fn apply_simplification(line: []u8, simplification: Simplification) ![]u8 {
    const allocator = std.heap.page_allocator;
    var new_line = try std.ArrayList(u8).initCapacity(allocator, line.len);

    try new_line.appendSlice(allocator, simplification.prefix);
    try append_num(&new_line, simplification.value);
    try new_line.appendSlice(allocator, simplification.suffix);

    return new_line.items;
}

fn print_intermediate_expr(expr: []u8) void {
    stdout_print("Expression simplified to: {s}\n", .{expr}) catch {};
}

fn parse_expr(orig_expr: []u8) !i128 {
    var expr = orig_expr;

    while (find_simplification(SECOND_ORDER_OP, expr)) |simplification| {
        expr = try apply_simplification(expr, simplification);
        print_intermediate_expr(expr);
    }

    while (find_simplification(FIRST_ORDER_OP, expr)) |simplification| {
        expr = try apply_simplification(expr, simplification);
        print_intermediate_expr(expr);
    }

    return try parse_i128(expr);
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
                try stdout_print("Successfully parsed. Result: {}\n", .{num});
                return std.process.cleanExit();
            }
        }
    }

    std.debug.print("{s}", .{usage});
    std.process.exit(1);
}
