const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/consistent-type-assertions";

pub const Options = struct {
    assertion_style: core.TypescriptEslintConsistentTypeAssertionsStyle,
    object_literal_type_assertions: core.TypescriptEslintLiteralTypeAssertions,
    array_literal_type_assertions: core.TypescriptEslintLiteralTypeAssertions,
};

pub fn checkAsExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.TSAsExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (isConstType(tree, expression.type_annotation)) return;

    if (try checkLiteralAssertion(allocator, diagnostics, tree, expression.expression, index, ctx, options)) return;

    const type_text = sourceText(tree, expression.type_annotation);
    switch (options.assertion_style) {
        .as => {},
        .angle_bracket => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(index),
            "Use '<{s}>' instead of 'as {s}'.",
            .{ type_text, type_text },
        ),
        .never => try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            "Do not use type assertions.",
            tree.span(index),
        ),
    }
}

pub fn checkTypeAssertion(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    assertion: ast.TSTypeAssertion,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (isConstType(tree, assertion.type_annotation)) return;
    if (try checkLiteralAssertion(allocator, diagnostics, tree, assertion.expression, index, ctx, options)) return;

    const type_text = sourceText(tree, assertion.type_annotation);

    switch (options.assertion_style) {
        .as => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(index),
            "Use 'as {s}' instead of '<{s}>'.",
            .{ type_text, type_text },
        ),
        .angle_bracket => {},
        .never => try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            "Do not use type assertions.",
            tree.span(index),
        ),
    }
}

fn checkLiteralAssertion(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NodeIndex,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!bool {
    const literal = literalAssertionKind(tree, expression) orelse return false;
    const mode = switch (literal) {
        .object => options.object_literal_type_assertions,
        .array => options.array_literal_type_assertions,
    };

    const allowed = switch (mode) {
        .allow => true,
        .allow_as_parameter => isParameterAssertion(tree, index, ctx),
        .never => false,
    };
    if (allowed) return false;

    const placeholder = switch (literal) {
        .object => "{ ... }",
        .array => "[ ... ]",
    };
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "Always prefer const x: T = {s}.",
        .{placeholder},
    );
    return true;
}

const LiteralAssertionKind = enum {
    object,
    array,
};

fn literalAssertionKind(tree: *const ast.Tree, index: ast.NodeIndex) ?LiteralAssertionKind {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .object_expression => .object,
        .array_expression => .array,
        else => null,
    };
}

fn isConstType(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .ts_type_reference => |reference| blk: {
            const name = typeName(tree, reference.type_name) orelse break :blk false;
            break :blk std.mem.eql(u8, name, "const");
        },
        else => false,
    };
}

fn typeName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            .chain_expression => |chain| current = chain.expression,
            else => return current,
        }
    }
    return current;
}

fn isParameterAssertion(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    var child = index;
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |parent_index| : (depth += 1) {
        switch (tree.data(parent_index)) {
            .parenthesized_expression => |parenthesized| {
                if (parenthesized.expression != child) return false;
                child = parent_index;
            },
            .chain_expression => |chain| {
                if (chain.expression != child) return false;
                child = parent_index;
            },
            .call_expression => |call| return rangeContains(tree, call.arguments, child),
            .new_expression => |new_expression| return rangeContains(tree, new_expression.arguments, child),
            else => return false,
        }
    }
    return false;
}

fn rangeContains(tree: *const ast.Tree, range: ast.IndexRange, index: ast.NodeIndex) bool {
    for (0..range.len) |i| {
        if (tree.extra(range)[i] == index) return true;
    }
    return false;
}

fn sourceText(tree: *const ast.Tree, index: ast.NodeIndex) []const u8 {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start > end or end > tree.source.len) return "T";
    return tree.source[start..end];
}
