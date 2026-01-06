const std = @import("std");
const tokenizer = @import("tokenizer.zig");

pub fn evaluate(root: *tokenizer.Group) !i128 {
    var prefix: i128 = 0;
    var block: ?i128 = null;
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

                        if (block_op.? == .add) {
                            prefix = try std.math.add(i128, prefix, val);
                        } else if (block_op.? == .sub) {
                            prefix = try std.math.sub(i128, prefix, val);
                        } else {
                            return error.todo;
                        }

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
            var num: i128 = undefined;
            if (tag == tokenizer.TokenTag.group) {
                num = try evaluate(token.group);
            } else {
                num = token.integer_literal.value;
            }
            if (block_op == null) {
                block_op = .add;
            }
            if (block == null) {
                block = num;
            } else {
                block = try std.math.mul(i128, block.?, num);
            }
        }
    }

    if (block) |val| {
        if (block_op == null) {
            return error.todo;
        }
        if (block_op.? == .add) {
            prefix = try std.math.add(i128, prefix, val);
        } else if (block_op.? == .sub) {
            prefix = try std.math.sub(i128, prefix, val);
        } else {
            return error.todo;
        }
    }

    return prefix;
}
