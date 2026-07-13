const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "prefer-numeric-literals";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    _: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (preferredLiteralKind(ctx.tree, call)) |kind| {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                diagnosticMessage(kind),
                ctx.tree.span(index),
            );
        }

        return .proceed;
    }
};

const LiteralKind = enum {
    binary,
    octal,
    hexadecimal,
};

fn preferredLiteralKind(
    tree: *const ast.Tree,
    call: ast.CallExpression,
) ?LiteralKind {
    if (!isParseIntCall(tree, call.callee)) return null;

    const arguments = tree.extra(call.arguments);
    if (arguments.len != 2) return null;

    _ = staticStringValue(tree, arguments[0]) orelse return null;
    const kind = radixLiteralKind(tree, arguments[1]) orelse return null;
    return kind;
}

fn diagnosticMessage(kind: LiteralKind) []const u8 {
    return switch (kind) {
        .binary => "Use a binary literal instead of parseInt().",
        .octal => "Use an octal literal instead of parseInt().",
        .hexadecimal => "Use a hexadecimal literal instead of parseInt().",
    };
}

fn staticStringValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    const unwrapped = unwrapTransparent(tree, index);
    return switch (tree.data(unwrapped)) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| if (tree.extra(literal.expressions).len == 0 and tree.extra(literal.quasis).len == 1)
            templateElementCooked(tree, tree.extra(literal.quasis)[0])
        else
            null,
        else => null,
    };
}

fn templateElementCooked(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn radixLiteralKind(tree: *const ast.Tree, index: ast.NodeIndex) ?LiteralKind {
    const unwrapped = unwrapTransparent(tree, index);
    const literal = switch (tree.data(unwrapped)) {
        .numeric_literal => |literal| literal,
        else => return null,
    };
    const value = literal.value(tree);
    if (value != @floor(value)) return null;

    const integer: i64 = @intFromFloat(value);
    return switch (integer) {
        2 => .binary,
        8 => .octal,
        16 => .hexadecimal,
        else => null,
    };
}

fn isParseIntCall(tree: *const ast.Tree, callee: ast.NodeIndex) bool {
    const unwrapped = unwrapTransparent(tree, callee);

    if (identifierReferenceName(tree, unwrapped)) |name| {
        return std.mem.eql(u8, name, "parseInt");
    }

    const member = switch (tree.data(unwrapped)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.property == .null) return false;

    const property = propertyName(tree, member) orelse return false;
    if (!std.mem.eql(u8, property, "parseInt")) return false;

    const object = unwrapTransparent(tree, member.object);
    const object_name = identifierReferenceName(tree, object) orelse return false;
    return std.mem.eql(u8, object_name, "Number");
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

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}
