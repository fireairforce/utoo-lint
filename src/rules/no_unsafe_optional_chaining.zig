const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-unsafe-optional-chaining";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    if (std.mem.indexOf(u8, tree.source, "?.") == null) return;

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,

    pub fn enter_chain_expression(
        self: *Visitor,
        _: ast.ChainExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const unsafe_parent = unsafeParent(ctx.tree, index, &ctx.path) orelse return .proceed;
        try self.addDiagnostic(ctx.tree, unsafe_parent.report_index);
        return .proceed;
    }

    fn addDiagnostic(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .@"error",
            id,
            "Unsafe usage of optional chaining. If it short-circuits with 'undefined' the evaluation will throw TypeError.",
            tree.span(index),
        );
    }
};

const UnsafeParent = struct {
    report_index: ast.NodeIndex,
};

fn unsafeParent(
    tree: *const ast.Tree,
    chain_index: ast.NodeIndex,
    path: *const traverser.NodePath,
) ?UnsafeParent {
    var child = chain_index;
    var depth: usize = 1;

    while (path.ancestor(depth)) |parent_index| : (depth += 1) {
        switch (tree.data(parent_index)) {
            .parenthesized_expression => |parenthesized| {
                if (parenthesized.expression != child) return null;
                child = parent_index;
                continue;
            },
            .ts_as_expression => |expression| {
                if (expression.expression != child) return null;
                child = parent_index;
                continue;
            },
            .ts_satisfies_expression => |expression| {
                if (expression.expression != child) return null;
                child = parent_index;
                continue;
            },
            .ts_type_assertion => |assertion| {
                if (assertion.expression != child) return null;
                child = parent_index;
                continue;
            },
            .ts_non_null_expression => |expression| {
                if (expression.expression != child) return null;
                child = parent_index;
                continue;
            },
            .ts_instantiation_expression => |expression| {
                if (expression.expression != child) return null;
                child = parent_index;
                continue;
            },
            else => return unsafeDirectParent(tree, parent_index, child, path, depth),
        }
    }

    return null;
}

fn unsafeDirectParent(
    tree: *const ast.Tree,
    parent_index: ast.NodeIndex,
    child: ast.NodeIndex,
    path: *const traverser.NodePath,
    parent_depth: usize,
) ?UnsafeParent {
    switch (tree.data(parent_index)) {
        .member_expression => |member| {
            if (member.object == child and !member.optional) return .{ .report_index = child };
        },
        .call_expression => |call| {
            if (call.callee == child and !call.optional) return .{ .report_index = child };
        },
        .new_expression => |expression| {
            if (expression.callee == child) return .{ .report_index = child };
        },
        .tagged_template_expression => |expression| {
            if (expression.tag == child) return .{ .report_index = child };
        },
        .spread_element => |spread| {
            if (spread.argument == child and isUnsafeSpreadParent(tree, path.ancestor(parent_depth + 1))) {
                return .{ .report_index = child };
            }
        },
        .for_in_statement => |statement| {
            if (statement.right == child) return .{ .report_index = child };
        },
        .for_of_statement => |statement| {
            if (statement.right == child) return .{ .report_index = child };
        },
        .with_statement => |statement| {
            if (statement.object == child) return .{ .report_index = child };
        },
        .binary_expression => |expression| {
            if (expression.right == child and isUnsafeBinaryOperator(expression.operator)) {
                return .{ .report_index = child };
            }
        },
        .variable_declarator => |declarator| {
            if (declarator.init == child and isDestructuringPattern(tree, declarator.id)) {
                return .{ .report_index = child };
            }
        },
        .assignment_expression => |expression| {
            if (expression.right == child and isDestructuringPattern(tree, expression.left)) {
                return .{ .report_index = child };
            }
        },
        .assignment_pattern => |pattern| {
            if (pattern.right == child and isDestructuringPattern(tree, pattern.left)) {
                return .{ .report_index = child };
            }
        },
        .class => |class| {
            if (class.super_class == child) return .{ .report_index = child };
        },
        else => {},
    }

    return null;
}

fn isUnsafeSpreadParent(tree: *const ast.Tree, parent: ?ast.NodeIndex) bool {
    const parent_index = parent orelse return false;
    return switch (tree.data(parent_index)) {
        .array_expression,
        .call_expression,
        .new_expression,
        => true,
        else => false,
    };
}

fn isUnsafeBinaryOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .in, .instanceof => true,
        else => false,
    };
}

fn isDestructuringPattern(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .array_pattern, .object_pattern => true,
        else => false,
    };
}
