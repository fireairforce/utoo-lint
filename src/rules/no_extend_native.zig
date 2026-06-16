const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-extend-native";

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

    pub fn enter_assignment_expression(
        self: *Visitor,
        expression: ast.AssignmentExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const left_member = switch (ctx.tree.data(unwrapTransparent(ctx.tree, expression.left))) {
            .member_expression => |member| member,
            else => return .proceed,
        };
        if (left_member.optional) return .proceed;

        if (nativePrototypeName(ctx.tree, left_member.object)) |name| {
            try report(self.allocator, self.diagnostics, ctx.tree, index, name);
        }

        return .proceed;
    }

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (!isObjectDefinePropertyCall(ctx.tree, call.callee)) return .proceed;

        const arguments = ctx.tree.extra(call.arguments);
        if (arguments.len == 0) return .proceed;

        if (nativePrototypeName(ctx.tree, arguments[0])) |name| {
            try report(self.allocator, self.diagnostics, ctx.tree, index, name);
        }

        return .proceed;
    }
};

fn nativePrototypeName(
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) ?[]const u8 {
    const member = switch (tree.data(unwrapTransparent(tree, index))) {
        .member_expression => |member| member,
        else => return null,
    };
    if (member.optional) return null;

    const property_name = propertyName(tree, member) orelse return null;
    if (!std.mem.eql(u8, property_name, "prototype")) return null;

    const object = unwrapTransparent(tree, member.object);
    const name = identifierReferenceName(tree, object) orelse return null;
    if (!isNativeConstructor(name)) return null;

    return name;
}

fn isObjectDefinePropertyCall(
    tree: *const ast.Tree,
    callee: ast.NodeIndex,
) bool {
    const member = switch (tree.data(unwrapTransparent(tree, callee))) {
        .member_expression => |member| member,
        else => return false,
    };

    const method = propertyName(tree, member) orelse return false;
    if (!std.mem.eql(u8, method, "defineProperty") and !std.mem.eql(u8, method, "defineProperties")) return false;

    const object = unwrapTransparent(tree, member.object);
    const object_name = identifierReferenceName(tree, object) orelse return false;
    return std.mem.eql(u8, object_name, "Object");
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

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isNativeConstructor(name: []const u8) bool {
    const constructors = [_][]const u8{
        "Array",
        "ArrayBuffer",
        "BigInt",
        "BigInt64Array",
        "BigUint64Array",
        "Boolean",
        "DataView",
        "Date",
        "Error",
        "EvalError",
        "Float32Array",
        "Float64Array",
        "Function",
        "Int8Array",
        "Int16Array",
        "Int32Array",
        "Map",
        "Number",
        "Object",
        "Promise",
        "RangeError",
        "ReferenceError",
        "RegExp",
        "Set",
        "String",
        "Symbol",
        "SyntaxError",
        "TypeError",
        "Uint8Array",
        "Uint8ClampedArray",
        "Uint16Array",
        "Uint32Array",
        "URIError",
        "WeakMap",
        "WeakSet",
    };

    for (constructors) |constructor| {
        if (std.mem.eql(u8, name, constructor)) return true;
    }
    return false;
}

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    name: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "{s} prototype is read only, properties should not be added.",
        .{name},
    );
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
