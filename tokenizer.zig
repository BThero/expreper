const std = @import("std");
const utils = @import("./utils.zig");

const DIGITS = "0123456789";
const FIRST_ORDER_OP = "+-";
const SECOND_ORDER_OP = "*";
const ALL_OP = FIRST_ORDER_OP ++ SECOND_ORDER_OP;

pub const TokenTag = enum {
    integer_literal,
    operator,
    group,
};

pub const IntType = i128;

pub const OperatorKind = enum { add, sub, mul };

pub const IntegerLiteral = struct {
    value: IntType,
    pub fn init(value: IntType) IntegerLiteral {
        return IntegerLiteral{ .value = value };
    }
    pub fn print(self: IntegerLiteral) void {
        std.log.info("integer_literal({})", .{self.value});
    }
};

pub const Operator = struct {
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

pub const Group = struct {
    tokens: std.array_list.Aligned(*Token, null),
    pub fn init(allocator: std.mem.Allocator) !Group {
        return Group{ .tokens = try std.ArrayList(*Token).initCapacity(allocator, 0) };
    }
    pub fn print(self: Group) void {
        std.log.info("group({}) -- enter", .{self.tokens.items.len});
        for (self.tokens.items) |token| {
            token.print();
        }
        std.log.info("group({}) -- exit", .{self.tokens.items.len});
    }
};

pub const Token = union(TokenTag) {
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

fn extract_num(allocator: std.mem.Allocator, num: *?i128) !?*Token {
    if (num.* == null) {
        return null;
    }

    const integer_literal = try allocator.create(IntegerLiteral);
    integer_literal.* = IntegerLiteral.init(num.*.?);

    const token = try allocator.create(Token);
    token.* = Token{ .integer_literal = integer_literal };

    num.* = null;
    return token;
}

pub fn tokenize(expr: []const u8) !*Token {
    const allocator = std.heap.page_allocator;
    const root_group = try allocator.create(Group);
    root_group.* = try Group.init(allocator);

    const root = try allocator.create(Token);
    root.* = Token{ .group = root_group };

    var num: ?i128 = null;

    var groupStack = try std.ArrayList(*Token).initCapacity(allocator, 0);
    try groupStack.append(allocator, root);

    for (expr) |ch| {
        const lastGroup = groupStack.items[groupStack.items.len - 1];
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
            if (try extract_num(allocator, &num)) |token| {
                try lastGroup.group.tokens.append(allocator, token);
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

            try lastGroup.group.tokens.append(allocator, token);
            continue;
        }
        if (ch == '(') {
            const group = try allocator.create(Group);
            group.* = try Group.init(allocator);

            const token = try allocator.create(Token);
            token.* = Token{ .group = group };

            try lastGroup.group.tokens.append(allocator, token);
            try groupStack.append(allocator, token);
            continue;
        }
        if (ch == ')') {
            if (try extract_num(allocator, &num)) |token| {
                try lastGroup.group.tokens.append(allocator, token);
            }

            _ = groupStack.pop();
            if (groupStack.items.len == 0) {
                return error.todo;
            }
            continue;
        }
        return error.todo;
    }

    if (groupStack.items.len != 1) {
        return error.todo;
    }

    if (try extract_num(allocator, &num)) |token| {
        try root.group.tokens.append(allocator, token);
    }

    return root;
}
