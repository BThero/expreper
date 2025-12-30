const std = @import("std");
const tokenizer = @import("./tokenizer.zig");

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

const DIGITS = "0123456789";
const FIRST_ORDER_OP = "+-";
const SECOND_ORDER_OP = "*";

fn parse_i128(expr: []u8) !i128 {
    return try std.fmt.parseInt(i128, expr, 10);
}

const ParseError = error{
    UnrecognizedOperator,
};

fn compute(lhs: i128, rhs: i128, op: u8) !i128 {
    return switch (op) {
        '+' => std.math.add(i128, lhs, rhs),
        '-' => std.math.sub(i128, lhs, rhs),
        '*' => std.math.mul(i128, lhs, rhs),
        else => ParseError.UnrecognizedOperator,
    };
}

fn parse_expr(expr: []u8) !i128 {
    // first, tokenize it
    const token = try tokenizer.tokenize(expr);
    token.print();
    return ParseError.UnrecognizedOperator;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);

    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
                std.log.info("{s}", .{usage});
                return std.process.cleanExit();
            }

            if (parse_expr(arg)) |num| {
                std.log.info("Successfully parsed. Result: {}\n", .{num});
                return std.process.cleanExit();
            } else |_| {
                std.log.err("Could not parse expression: '{s}'\n", .{arg});
                std.process.exit(1);
            }
        }
    }

    std.log.info("{s}", .{usage});
    std.process.exit(1);
}
