const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "for-direction";

const Direction = enum {
    increasing,
    decreasing,

    fn opposite(self: Direction) Direction {
        return switch (self) {
            .increasing => .decreasing,
            .decreasing => .increasing,
        };
    }
};

const UpdateCounter = struct {
    name: []const u8,
    direction: Direction,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ForStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (statement.@"test" == .null or statement.update == .null) return;

    if (!updateMovesOpposite(tree, statement.@"test", statement.update)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "The update clause in this loop moves the variable in the wrong direction.",
        tree.span(index),
    );
}

fn expectedDirection(
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    counter_name: []const u8,
) ?Direction {
    const expression = switch (tree.data(unwrapTransparent(tree, index))) {
        .binary_expression => |expression| expression,
        else => return null,
    };

    const left_name = identifierName(tree, expression.left);
    const right_name = identifierName(tree, expression.right);

    return switch (expression.operator) {
        .less_than,
        .less_than_or_equal,
        => if (matchesName(left_name, counter_name))
            .increasing
        else if (matchesName(right_name, counter_name))
            .decreasing
        else
            null,

        .greater_than,
        .greater_than_or_equal,
        => if (matchesName(left_name, counter_name))
            .decreasing
        else if (matchesName(right_name, counter_name))
            .increasing
        else
            null,

        else => null,
    };
}

fn updateMovesOpposite(
    tree: *const ast.Tree,
    test_index: ast.NodeIndex,
    update_index: ast.NodeIndex,
) bool {
    switch (tree.data(unwrapTransparent(tree, update_index))) {
        .sequence_expression => |sequence| {
            for (tree.extra(sequence.expressions)) |expression| {
                if (updateMovesOpposite(tree, test_index, expression)) return true;
            }
            return false;
        },
        else => {
            const update = updateCounter(tree, update_index) orelse return false;
            const expected = expectedDirection(tree, test_index, update.name) orelse return false;
            return update.direction == expected.opposite();
        },
    }
}

fn matchesName(maybe_name: ?[]const u8, name: []const u8) bool {
    const value = maybe_name orelse return false;
    return std.mem.eql(u8, value, name);
}

fn updateCounter(tree: *const ast.Tree, index: ast.NodeIndex) ?UpdateCounter {
    switch (tree.data(unwrapTransparent(tree, index))) {
        .update_expression => |expression| {
            const name = identifierName(tree, expression.argument) orelse return null;
            const direction: Direction = switch (expression.operator) {
                .increment => .increasing,
                .decrement => .decreasing,
            };
            return .{ .name = name, .direction = direction };
        },
        .assignment_expression => |expression| return assignmentUpdateCounter(tree, expression),
        else => return null,
    }
}

fn assignmentUpdateCounter(tree: *const ast.Tree, expression: ast.AssignmentExpression) ?UpdateCounter {
    const left_name = identifierName(tree, expression.left) orelse return null;

    switch (expression.operator) {
        .add_assign => {
            const direction = signedDirection(tree, expression.right) orelse .increasing;
            return .{ .name = left_name, .direction = direction };
        },
        .subtract_assign => {
            const direction = if (signedDirection(tree, expression.right)) |direction|
                direction.opposite()
            else
                Direction.decreasing;
            return .{ .name = left_name, .direction = direction };
        },
        .assign => {
            const binary = switch (tree.data(unwrapTransparent(tree, expression.right))) {
                .binary_expression => |binary| binary,
                else => return null,
            };
            return assignmentBinaryUpdateCounter(tree, left_name, binary);
        },
        else => return null,
    }
}

fn assignmentBinaryUpdateCounter(
    tree: *const ast.Tree,
    left_name: []const u8,
    binary: ast.BinaryExpression,
) ?UpdateCounter {
    switch (binary.operator) {
        .add => {
            if (identifierName(tree, binary.left)) |name| {
                if (std.mem.eql(u8, name, left_name)) {
                    const direction = signedDirection(tree, binary.right) orelse .increasing;
                    return .{ .name = left_name, .direction = direction };
                }
            }
            if (identifierName(tree, binary.right)) |name| {
                if (std.mem.eql(u8, name, left_name)) {
                    const direction = signedDirection(tree, binary.left) orelse .increasing;
                    return .{ .name = left_name, .direction = direction };
                }
            }
            return null;
        },
        .subtract => {
            if (identifierName(tree, binary.left)) |name| {
                if (std.mem.eql(u8, name, left_name)) {
                    const direction = if (signedDirection(tree, binary.right)) |direction|
                        direction.opposite()
                    else
                        Direction.decreasing;
                    return .{ .name = left_name, .direction = direction };
                }
            }
            return null;
        },
        else => return null,
    }
}

fn signedDirection(tree: *const ast.Tree, index: ast.NodeIndex) ?Direction {
    if (index == .null) return null;

    switch (tree.data(unwrapTransparent(tree, index))) {
        .numeric_literal => |literal| {
            const raw = tree.string(literal.raw);
            if (std.mem.startsWith(u8, raw, "-")) return .decreasing;
            return .increasing;
        },
        .unary_expression => |expression| {
            const direction = signedDirection(tree, expression.argument) orelse return null;
            return switch (expression.operator) {
                .negate => direction.opposite(),
                .positive => direction,
                else => null,
            };
        },
        else => return null,
    }
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;

    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }

    return current;
}
