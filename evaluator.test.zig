const std = @import("std");
const evaluator = @import("evaluator.zig");
const tokenizer = @import("tokenizer.zig");

fn eval(expr: []const u8) !i128 {
    const token = try tokenizer.tokenize(expr);
    return try evaluator.evaluate(token.group);
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
    try std.testing.expectEqual(123, eval("123"));
    try std.testing.expectEqual(-456, eval("-456"));
}

test "addition" {
    try std.testing.expectEqual(3, eval("1+2"));
    try std.testing.expectEqual(-75, eval("-120+45"));
}

test "subtraction" {
    try std.testing.expectEqual(-1, eval("1-2"));
    try std.testing.expectEqual(-165, eval("-120-45"));
}

test "multiplication" {
    try std.testing.expectEqual(96, eval("12*8"));
    try std.testing.expectEqual(-20, eval("-4*5"));
}

test "brackets" {
    try std.testing.expectEqual(27, eval("3*(4+5)"));
    try std.testing.expectEqual(-16, eval("(1-5)*(3-(-1))"));
}

test "invalid expressions" {
    // proper error handling is not done yet, so we just expect a random error
    try expect_anyerror(eval(")"));
    try expect_anyerror(eval("1++2"));
    try expect_anyerror(eval("1--2"));
    try expect_anyerror(eval("--5"));
    try expect_anyerror(eval("298347530947532947535273904725759689400923485309580938509830398509348530")); // too big to fit in i128
    try expect_anyerror(eval("9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9*9"));
    // TODO: examples below are still being parsed
    // try expect_anyerror(eval("(-1-)"));
    // try expect_anyerror(eval("2**3"));
    try expect_anyerror(eval("(1+2))"));
}
