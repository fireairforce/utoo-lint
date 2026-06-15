const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-duplicate-enum-values";

const EnumValue = union(enum) {
    string: []const u8,
    number: f64,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.TSEnumDeclaration,
) Allocator.Error!void {
    const body = switch (tree.data(declaration.body)) {
        .ts_enum_body => |body| body,
        else => return,
    };

    var seen: std.ArrayList(EnumValue) = .empty;
    defer seen.deinit(allocator);

    for (tree.extra(body.members)) |member_index| {
        const member = switch (tree.data(member_index)) {
            .ts_enum_member => |member| member,
            else => continue,
        };
        const value = literalEnumValue(tree, member.initializer) orelse continue;

        for (seen.items) |seen_value| {
            if (enumValuesEqual(seen_value, value)) {
                try core.addDiagnostic(
                    allocator,
                    diagnostics,
                    .@"error",
                    id,
                    "Duplicate enum member value.",
                    tree.span(member.initializer),
                );
                break;
            }
        } else {
            try seen.append(allocator, value);
        }
    }
}

fn literalEnumValue(tree: *const ast.Tree, index: ast.NodeIndex) ?EnumValue {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .string_literal => |literal| .{ .string = tree.string(literal.value) },
        .template_literal => |literal| templateLiteralValue(tree, literal),
        .numeric_literal => |literal| .{ .number = literal.value(tree) },
        .unary_expression => |expression| signedNumericLiteralValue(tree, expression),
        else => null,
    };
}

fn signedNumericLiteralValue(tree: *const ast.Tree, expression: ast.UnaryExpression) ?EnumValue {
    const number = switch (tree.data(expression.argument)) {
        .numeric_literal => |literal| literal.value(tree),
        else => return null,
    };

    return switch (expression.operator) {
        .negate => .{ .number = -number },
        .positive => .{ .number = number },
        else => null,
    };
}

fn templateLiteralValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?EnumValue {
    if (tree.extra(literal.expressions).len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len != 1) return null;

    return switch (tree.data(quasis[0])) {
        .template_element => |element| .{ .string = tree.string(element.cooked) },
        else => null,
    };
}

fn enumValuesEqual(left: EnumValue, right: EnumValue) bool {
    return switch (left) {
        .string => |left_string| switch (right) {
            .string => |right_string| std.mem.eql(u8, left_string, right_string),
            .number => false,
        },
        .number => |left_number| switch (right) {
            .string => false,
            .number => |right_number| left_number == right_number,
        },
    };
}
