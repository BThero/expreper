const std = @import("std");
const tokenizer = @import("./tokenizer.zig");
const evaluator = @import("./evaluator.zig");

const usage =
    \\Usage: ./expreper [options] [expr]
    \\
    \\Options:
    \\ -h, --help: Show this usage information
    \\Expr:
    \\ A simple mathematical expression which consists of integers, decimals and '+', '-', '*' operators.
    \\
    \\ Calculations are done in integers when possible. 
;

fn parse_expr(expr: []u8) !evaluator.Result {
    const token = try tokenizer.tokenize(expr);
    const result = try evaluator.evaluate(token.group);
    return result;
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

            if (parse_expr(arg)) |result| {
                if (result.is_integer()) {
                    std.log.info("Successfully parsed. Result is an integer: {}\n", .{result.integer});
                } else {
                    std.log.info("Successfully parsed. Result is a decimal: {d:.6}\n", .{result.decimal});
                }
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
