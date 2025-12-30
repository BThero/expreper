const std = @import("std");
const utils = @import("./utils.zig");

const DIGITS = "0123456789";
const FIRST_ORDER_OP = "+-";
const SECOND_ORDER_OP = "*";
const ALL_OP = FIRST_ORDER_OP ++ SECOND_ORDER_OP;

const TokenTag = enum {
    integer_literal,
    operator,
    group,
};

const IntType = i128;

const OperatorKind = enum { add, sub, mul };

const IntegerLiteral = struct {
    value: IntType,
    pub fn init(value: IntType) IntegerLiteral {
        return IntegerLiteral{ .value = value };
    }
    pub fn print(self: IntegerLiteral) void {
        std.log.info("integer_literal({})", .{self.value});
    }
};

const Operator = struct {
    kind: OperatorKind,
    pub fn init(kind: OperatorKind) Operator {
        return Operator{ .kind = kind };
    }
    pub fn print(self: Operator) void {
        const str = switch (self.kind) {
            .add => "add",
            .sub => "sub",
            .mul => "mul",
        };
        std.log.info("operator({s})", .{str});
    }
};

const Group = struct {
    tokens: []*Token,
    token_builder: std.array_list.Aligned(*Token, null),
    eval: ?IntType = null,
    pub fn print(self: Group) void {
        std.log.info("group({}) -- enter", .{self.tokens.len});
        for (self.tokens) |token| {
            token.print();
        }
        std.log.info("group({}) -- exit", .{self.tokens.len});
    }
};

const Token = union(TokenTag) {
    integer_literal: *IntegerLiteral,
    operator: *Operator,
    group: *Group,

    pub fn print(self: Token) void {
        switch (self) {
            .integer_literal => {
                self.integer_literal.print();
            },
            .operator => {
                self.operator.print();
            },
            .group => {
                self.group.print();
            },
        }
    }
};

pub fn tokenize(expr: []const u8) !*Token {
    const allocator = std.heap.page_allocator;
    const root_group = try allocator.create(Group);
    root_group.token_builder = try std.ArrayList(*Token).initCapacity(allocator, 0);

    const root = try allocator.create(Token);
    root.* = Token{ .group = root_group };

    var num: ?i128 = null;

    for (expr) |ch| {
        if (utils.is_one_of(DIGITS, ch)) {
            if (num == null) {
                num = ch - '0';
            } else {
                num = try std.math.mul(i128, num.?, 10);
                num = try std.math.add(i128, num.?, ch - '0');
            }
            continue;
        }
        if (utils.is_one_of(ALL_OP, ch)) {
            if (num != null) {
                const integer_literal = try allocator.create(IntegerLiteral);
                integer_literal.* = IntegerLiteral.init(num.?);

                const token = try allocator.create(Token);
                token.* = Token{ .integer_literal = integer_literal };

                try root.group.token_builder.append(allocator, token);
                num = null;
            }

            const operator_kind = try switch (ch) {
                '+' => OperatorKind.add,
                '-' => OperatorKind.sub,
                '*' => OperatorKind.mul,
                else => error.todo,
            };
            const operator = try allocator.create(Operator);
            operator.* = Operator.init(operator_kind);

            const token = try allocator.create(Token);
            token.* = Token{ .operator = operator };

            try root.group.token_builder.append(allocator, token);
        }
    }

    if (num != null) {
        const integer_literal = try allocator.create(IntegerLiteral);
        integer_literal.* = IntegerLiteral.init(num.?);

        const token = try allocator.create(Token);
        token.* = Token{ .integer_literal = integer_literal };

        try root.group.token_builder.append(allocator, token);
        num = null;
    }

    root.group.tokens = root.group.token_builder.items;
    return root;
}
