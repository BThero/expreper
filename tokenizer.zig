const std = @import("std");
const utils = @import("./utils.zig");

const DIGITS = "0123456789";
const FIRST_ORDER_OP = "+-";
const SECOND_ORDER_OP = "*";
const ALL_OP = FIRST_ORDER_OP ++ SECOND_ORDER_OP;
const DIGITS_AND_DOT = DIGITS ++ ".";

pub const TokenTag = enum {
    integer_literal,
    decimal_literal,
    operator,
    group,
};

pub const IntType = i128;
pub const DecimalType = f128;

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

pub const DecimalLiteral = struct {
    value: DecimalType,
    pub fn init(value: DecimalType) DecimalLiteral {
        return DecimalLiteral{ .value = value };
    }
    pub fn print(self: DecimalLiteral) void {
        std.log.info("decimal_literal({})", .{self.value});
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
    decimal_literal: *DecimalLiteral,
    operator: *Operator,
    group: *Group,

    pub fn print(self: Token) void {
        switch (self) {
            .integer_literal => {
                self.integer_literal.print();
            },
            .decimal_literal => {
                self.decimal_literal.print();
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

const NumStage = enum { empty, int, dot, decimal };

const Num = struct {
    stage: NumStage,
    int: IntType,
    decimal: IntType,
    decimal_len: usize,
    pub fn init() Num {
        return Num{ .stage = NumStage.empty, .int = undefined, .decimal = undefined, .decimal_len = undefined };
    }
    pub fn append_char(self: Num, ch: u8) !Num {
        if (ch == '.') {
            if (self.stage != NumStage.int) {
                return error.todo;
            }
            return Num{ .stage = NumStage.dot, .int = self.int, .decimal = undefined, .decimal_len = undefined };
        }
        if (ch < '0' or ch > '9') {
            return error.todo;
        }
        const digit: IntType = ch - '0';
        return try switch (self.stage) {
            NumStage.empty => {
                return Num{ .stage = NumStage.int, .int = digit, .decimal = undefined, .decimal_len = undefined };
            },
            NumStage.int => {
                if (self.int == 0) {
                    return error.todo; // leading zero case
                }
                var new_int = try std.math.mul(IntType, self.int, 10);
                new_int = try std.math.add(IntType, new_int, digit);
                return Num{ .stage = NumStage.int, .int = new_int, .decimal = undefined, .decimal_len = undefined };
            },
            NumStage.dot => {
                return Num{ .stage = NumStage.decimal, .int = self.int, .decimal = digit, .decimal_len = 1 };
            },
            NumStage.decimal => {
                // no need to handle leading zero case, since 12.00 is OK
                var new_decimal = try std.math.mul(IntType, self.decimal, 10);
                new_decimal = try std.math.add(IntType, new_decimal, digit);
                return Num{ .stage = NumStage.decimal, .int = self.int, .decimal = new_decimal, .decimal_len = self.decimal_len + 1 };
            },
        };
    }
};

fn extract_num(allocator: std.mem.Allocator, num: *Num) !?*Token {
    return try switch (num.stage) {
        NumStage.empty => {
            return null;
        },
        NumStage.int, NumStage.dot => {
            // We can treat "12." as 12
            const integer_literal = try allocator.create(IntegerLiteral);
            integer_literal.* = IntegerLiteral.init(num.int);
            num.* = Num.init();

            const token = try allocator.create(Token);
            token.* = Token{ .integer_literal = integer_literal };
            return token;
        },
        NumStage.decimal => {
            const value = @as(DecimalType, @floatFromInt(num.int)) +
                @as(DecimalType, @floatFromInt(num.decimal)) / try switch (num.decimal_len) {
                    1 => @as(DecimalType, 10.0),
                    2 => @as(DecimalType, 100.0),
                    3 => @as(DecimalType, 1_000.0),
                    4 => @as(DecimalType, 10_000.0),
                    5 => @as(DecimalType, 100_000.0),
                    6 => @as(DecimalType, 1_000_000.0),
                    else => error.todo, // too many digits after the dot
                };
            const decimal_literal = try allocator.create(DecimalLiteral);
            decimal_literal.* = DecimalLiteral.init(value);
            num.* = Num.init();

            const token = try allocator.create(Token);
            token.* = Token{ .decimal_literal = decimal_literal };
            return token;
        },
    };
}

pub fn tokenize(expr: []const u8) !*Token {
    const allocator = std.heap.page_allocator;
    const root_group = try allocator.create(Group);
    root_group.* = try Group.init(allocator);

    const root = try allocator.create(Token);
    root.* = Token{ .group = root_group };

    var num = Num.init();

    var groupStack = try std.ArrayList(*Token).initCapacity(allocator, 0);
    try groupStack.append(allocator, root);

    for (expr) |ch| {
        const lastGroup = groupStack.items[groupStack.items.len - 1];
        if (utils.is_one_of(DIGITS_AND_DOT, ch)) {
            num = try num.append_char(ch);
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
