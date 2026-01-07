const std = @import("std");
const tokenizer = @import("tokenizer.zig");

const ResultTag = enum {
    integer,
    decimal,
};

const IntType = tokenizer.IntType;
const DecimalType = tokenizer.DecimalType;

pub const Result = union(ResultTag) {
    integer: IntType,
    decimal: DecimalType,
    pub fn is_integer(self: Result) bool {
        return @as(ResultTag, self) == ResultTag.integer;
    }
    pub fn is_decimal(self: Result) bool {
        return @as(ResultTag, self) == ResultTag.decimal;
    }
    pub fn op(self: Result, other: Result, kind: tokenizer.OperatorKind) !Result {
        if (self.is_integer() and other.is_integer()) {
            const result = try switch (kind) {
                .add => std.math.add(IntType, self.integer, other.integer),
                .sub => std.math.sub(IntType, self.integer, other.integer),
                .mul => std.math.mul(IntType, self.integer, other.integer),
            };
            return Result{ .integer = result };
        }
        const dec_self = if (self.is_integer())
            @as(DecimalType, @floatFromInt(self.integer))
        else
            self.decimal;
        const dec_other = if (other.is_integer())
            @as(DecimalType, @floatFromInt(other.integer))
        else
            other.decimal;
        const result = switch (kind) {
            .add => dec_self + dec_other,
            .sub => dec_self - dec_other,
            .mul => dec_self * dec_other,
        };
        return Result{ .decimal = result };
    }
};

pub fn evaluate(root: *tokenizer.Group) !Result {
    var prefix = Result{ .integer = 0 };
    var block: ?Result = null;
    var block_op: ?tokenizer.OperatorKind = null;

    // [....]   (+/-)      (x1*x2*x3*x4)
    // ^prefix  ^block_op  ^block

    for (root.tokens.items) |token| {
        const tag = @as(tokenizer.TokenTag, token.*);
        if (tag == tokenizer.TokenTag.operator) {
            switch (token.operator.kind) {
                .add, .sub => {
                    if (block) |val| {
                        if (block_op == null) {
                            return error.todo;
                        }
                        prefix = try prefix.op(val, block_op.?);
                        block = null;
                        block_op = null;
                    }
                    if (block_op != null) {
                        return error.todo;
                    } else {
                        block_op = token.operator.kind;
                    }
                },
                .mul => {
                    if (block == null or block_op == null) {
                        return error.todo;
                    }
                },
            }
        } else {
            var num: Result = undefined;
            if (tag == tokenizer.TokenTag.group) {
                num = try evaluate(token.group);
            } else if (tag == tokenizer.TokenTag.integer_literal) {
                num = Result{ .integer = token.integer_literal.value };
            } else if (tag == tokenizer.TokenTag.decimal_literal) {
                num = Result{ .decimal = token.decimal_literal.value };
            } else {
                return error.todo;
            }
            if (block_op == null) {
                block_op = .add;
            }
            if (block == null) {
                block = num;
            } else {
                block = try block.?.op(num, tokenizer.OperatorKind.mul);
            }
        }
    }

    if (block) |val| {
        if (block_op == null) {
            return error.todo;
        }
        prefix = try prefix.op(val, block_op.?);
        block = null;
        block_op = null;
    }

    return prefix;
}
