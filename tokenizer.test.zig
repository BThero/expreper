const std = @import("std");
const tokenizer = @import("tokenizer.zig");

fn expect_group(token: *tokenizer.Token) ![](*tokenizer.Token) {
    try std.testing.expectEqual(tokenizer.TokenTag.group, @as(tokenizer.TokenTag, token.*));
    const group = token.group;
    return group.tokens.items;
}

fn expect_int(token: *tokenizer.Token) !tokenizer.IntType {
    try std.testing.expectEqual(tokenizer.TokenTag.integer_literal, @as(tokenizer.TokenTag, token.*));
    const integer_literal = token.integer_literal;
    return integer_literal.value;
}

fn expect_decimal(token: *tokenizer.Token) !tokenizer.DecimalType {
    try std.testing.expectEqual(tokenizer.TokenTag.decimal_literal, @as(tokenizer.TokenTag, token.*));
    const decimal_literal = token.decimal_literal;
    return decimal_literal.value;
}

fn expect_operator(token: *tokenizer.Token) !tokenizer.OperatorKind {
    try std.testing.expectEqual(tokenizer.TokenTag.operator, @as(tokenizer.TokenTag, token.*));
    const operator = token.operator;
    return operator.kind;
}

test "integer" {
    const nums = [_]i128{ 13, 2026, 948768574 };
    var buf: [100]u8 = undefined;

    for (nums) |num| {
        const expr = try std.fmt.bufPrint(&buf, "{}", .{num});

        const root = try tokenizer.tokenize(expr);
        const items = try expect_group(root);

        try std.testing.expectEqual(1, items.len);
        try std.testing.expectEqual(num, try expect_int(items[0]));
    }
}

test "decimal" {
    const tolerance: tokenizer.DecimalType = 1e-9;
    const expressions: [3][]const u8 = .{ "12.045", "4567.9", "5.00" };
    const decimals = [_]tokenizer.DecimalType{ 12.045, 4567.9, 5 };
    std.debug.assert(expressions.len == decimals.len);

    for (0..expressions.len) |i| {
        const expr = expressions[i];
        const expected = decimals[i];

        const root = try tokenizer.tokenize(expr);
        const items = try expect_group(root);

        try std.testing.expectEqual(1, items.len);
        try std.testing.expectApproxEqAbs(expected, try expect_decimal(items[0]), tolerance);
    }
}

test "operator" {
    const operators = [_]u8{ '*', '+', '-' };
    var buf: [100]u8 = undefined;

    for (operators) |operator| {
        const expr = try std.fmt.bufPrint(&buf, "{c}", .{operator});

        const root = try tokenizer.tokenize(expr);
        const items = try expect_group(root);

        try std.testing.expectEqual(1, items.len);
        try std.testing.expectEqual(switch (operator) {
            '*' => tokenizer.OperatorKind.mul,
            '+' => tokenizer.OperatorKind.add,
            '-' => tokenizer.OperatorKind.sub,
            else => error.unexpected_operator,
        }, try expect_operator(items[0]));
    }
}

test "group" {
    const expr = "(1+2*3-4+5*6-7)";

    const root = try tokenizer.tokenize(expr);
    const group = (try expect_group(root))[0];
    const items = try expect_group(group);

    try std.testing.expectEqual(13, items.len);
}

test "mix" {
    const root = try tokenizer.tokenize("5+3*(7-(1+2)-3)");
    const group0 = try expect_group(root);
    try std.testing.expectEqual(5, group0.len);
    try std.testing.expectEqual(5, try expect_int(group0[0]));
    try std.testing.expectEqual(tokenizer.OperatorKind.add, try expect_operator(group0[1]));
    try std.testing.expectEqual(3, try expect_int(group0[2]));
    try std.testing.expectEqual(tokenizer.OperatorKind.mul, try expect_operator(group0[3]));
    const group1 = try expect_group(group0[4]);

    try std.testing.expectEqual(5, group1.len);
    try std.testing.expectEqual(7, try expect_int(group1[0]));
    try std.testing.expectEqual(tokenizer.OperatorKind.sub, try expect_operator(group1[1]));
    const group2 = try expect_group(group1[2]);
    try std.testing.expectEqual(tokenizer.OperatorKind.sub, try expect_operator(group1[3]));
    try std.testing.expectEqual(3, try expect_int(group1[4]));

    try std.testing.expectEqual(3, group2.len);
    try std.testing.expectEqual(1, try expect_int(group2[0]));
    try std.testing.expectEqual(tokenizer.OperatorKind.add, try expect_operator(group2[1]));
    try std.testing.expectEqual(2, try expect_int(group2[2]));
}
