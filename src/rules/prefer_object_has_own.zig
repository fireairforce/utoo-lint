const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "prefer-object-has-own";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (!isPreferableHasOwn(ctx.tree, self.symbol_table, call)) return .proceed;

        const callee_span = ctx.tree.span(call.callee);
        if (hasCommentInside(ctx.tree, callee_span) or hasOptionalChainInside(ctx.tree.source, callee_span)) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                "Use 'Object.hasOwn()' instead of 'Object.prototype.hasOwnProperty.call()'.",
                ctx.tree.span(index),
            );
            return .proceed;
        }

        try core.addDiagnosticWithFix(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "Use 'Object.hasOwn()' instead of 'Object.prototype.hasOwnProperty.call()'.",
            ctx.tree.span(index),
            .{
                .span = callee_span,
                .replacement = if (needsSpaceBefore(ctx.tree.source, callee_span)) " Object.hasOwn" else "Object.hasOwn",
            },
        );

        return .proceed;
    }
};

fn isPreferableHasOwn(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    call: ast.CallExpression,
) bool {
    const arguments = tree.extra(call.arguments);
    if (arguments.len < 2) return false;

    const call_member = memberExpression(tree, call.callee) orelse return false;
    if (!propertyNamed(tree, call_member, "call")) return false;

    const target_member = memberExpression(tree, call_member.object) orelse return false;
    if (!propertyNamed(tree, target_member, "hasOwnProperty")) return false;

    return isPreferredTargetObject(tree, symbol_table, target_member.object);
}

fn isPreferredTargetObject(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const object = unwrapTransparent(tree, index);

    if (isObjectLiteral(tree, object)) return true;

    if (isIdentifierReference(tree, object, "Object")) {
        return isUnresolvedReference(symbol_table, object);
    }

    const prototype_member = memberExpression(tree, object) orelse return false;
    if (!propertyNamed(tree, prototype_member, "prototype")) return false;

    const prototype_object = unwrapTransparent(tree, prototype_member.object);
    if (!isIdentifierReference(tree, prototype_object, "Object")) return false;
    return isUnresolvedReference(symbol_table, prototype_object);
}

fn memberExpression(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.MemberExpression {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .member_expression => |member| member,
        else => null,
    };
}

fn isObjectLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .object_expression => |object| tree.extra(object.properties).len == 0,
        else => false,
    };
}

fn hasCommentInside(tree: *const ast.Tree, span: ast.Span) bool {
    for (tree.comments) |comment| {
        if (comment.span.start >= span.start and comment.span.end <= span.end) return true;
    }
    return false;
}

fn hasOptionalChainInside(source: []const u8, span: ast.Span) bool {
    return std.mem.indexOf(u8, source[span.start..span.end], "?.") != null;
}

fn needsSpaceBefore(source: []const u8, span: ast.Span) bool {
    const start: usize = @intCast(span.start);
    return start > 0 and isIdentifierPart(source[start - 1]);
}

fn isIdentifierPart(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$' or byte >= 0x80;
}

fn propertyNamed(tree: *const ast.Tree, member: ast.MemberExpression, expected: []const u8) bool {
    const name = propertyName(tree, member) orelse return false;
    return std.mem.eql(u8, name, expected);
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return if (member.computed)
        switch (tree.data(member.property)) {
            .string_literal => |literal| tree.string(literal.value),
            .template_literal => |literal| templateStringValue(tree, literal),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";

    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn isIdentifierReference(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), expected),
        else => false,
    };
}

fn isUnresolvedReference(
    symbol_table: traverser.semantic.SymbolTable,
    node: ast.NodeIndex,
) bool {
    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        if (entry.reference.node == node) {
            return symbol_table.referenceSymbol(entry.id) == .none;
        }
    }

    return false;
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
