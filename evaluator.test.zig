const std = @import("std");
const evaluator = @import("evaluator.zig");
const tokenizer = @import("tokenizer.zig");

const tolerance: tokenizer.DecimalType = 1e-9;

fn eval_integer(expr: []const u8) !i128 {
    const token = try tokenizer.tokenize(expr);
    const result = try evaluator.evaluate(token.group);
    return result.integer;
}

fn eval_decimal(expr: []const u8) !f128 {
    const token = try tokenizer.tokenize(expr);
    const result = try evaluator.evaluate(token.group);
    return result.decimal;
}

fn expect_anyerror(value: anytype) !void {
    if (value) |_| {
        std.debug.print("expected any error, found {any}\n", .{value});
        return error.ExpectedError;
    } else |_| {
        // all good
    }
}

test "integer" {
    try std.testing.expectEqual(123, eval_integer("123"));
    try std.testing.expectEqual(-456, eval_integer("-456"));
}

test "decimal" {
    try std.testing.expectApproxEqAbs(5.5, try eval_decimal("5.5"), tolerance);
    try std.testing.expectApproxEqAbs(-3.035, try eval_decimal("-3.035"), tolerance);
}

test "addition" {
    try std.testing.expectEqual(3, eval_integer("1+2"));
    try std.testing.expectEqual(-75, eval_integer("-120+45"));
    try std.testing.expectApproxEqAbs(4.75, try eval_decimal("-1.23+3.47+2.51"), tolerance);
}

test "subtraction" {
    try std.testing.expectEqual(-1, eval_integer("1-2"));
    try std.testing.expectEqual(-165, eval_integer("-120-45"));
    try std.testing.expectApproxEqAbs(-9.88, try eval_decimal("4.52-9.08-5.320"), tolerance);
}

test "multiplication" {
    try std.testing.expectEqual(96, eval_integer("12*8"));
    try std.testing.expectEqual(-20, eval_integer("-4*5"));
    try std.testing.expectApproxEqAbs(24.51, try eval_decimal("4.3*5.7"), tolerance);
}

test "brackets" {
    try std.testing.expectEqual(27, eval_integer("3*(4+5)"));
    try std.testing.expectEqual(-16, eval_integer("(1-5)*(3-(-1))"));
}

test "invalid expressions" {
    // proper error handling is not done yet, so we just expect a random error
    try expect_anyerror(eval_integer(")"));
    try expect_anyerror(eval_integer("1++2"));
    try expect_anyerror(eval_integer("1--2"));
    try expect_anyerror(eval_integer("--5"));
    try expect_anyerror(eval_integer("298347530947532947535273904725759689400923485309580938509830398509348530")); // too big to fit in i128
    try expect_anyerror(eval_integer("9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9"));
    // TODO: examples below are still being parsed
    // try expect_anyerror(eval("(-1-)"));
    // try expect_anyerror(eval("2**3"));
    try expect_anyerror(eval_integer("(1+2))"));
    try expect_anyerror(eval_decimal("1..5"));
    try expect_anyerror(eval_decimal("2.3.0"));
    try expect_anyerror(eval_decimal("005"));
}
