const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "promise/catch-or-return";

pub const Options = struct {
    allow_finally: bool = false,
    allow_then: bool = false,
    allow_then_strict: bool = false,
    termination_methods: core.PromiseCatchOrReturnTerminationMethods = .{},
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ExpressionStatement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const expression = unwrapTransparent(tree, statement.expression);
    if (!isPromise(tree, expression)) return;
    if (isAllowedTermination(tree, expression, &options)) return;
    if (isMemberCallRootedAt(tree, expression, "cy")) return;

    if (!options.termination_methods.custom) {
        try addDiagnostic(allocator, diagnostics, tree, index, "catch");
        return;
    }

    var method_names: [core.max_promise_catch_or_return_termination_methods][]const u8 = undefined;
    for (0..options.termination_methods.count) |method_index| {
        method_names[method_index] = options.termination_methods.at(method_index);
    }
    const display = try std.mem.join(allocator, ",", method_names[0..options.termination_methods.count]);
    defer allocator.free(display);
    try addDiagnostic(allocator, diagnostics, tree, index, display);
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    termination_methods: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Expected {s}() or return",
        .{termination_methods},
    );
}

fn isAllowedTermination(tree: *const ast.Tree, expression_index: ast.NodeIndex, options: *const Options) bool {
    const expression = switch (tree.data(unwrapTransparent(tree, expression_index))) {
        .call_expression => |call| call,
        else => return false,
    };
    const member = switch (tree.data(unwrapTransparent(tree, expression.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    const property_name = memberPropertyIdentifierName(tree, member);
    const arguments = tree.extra(expression.arguments);

    if ((options.allow_then or options.allow_then_strict) and
        property_name != null and
        std.mem.eql(u8, property_name.?, "then") and
        arguments.len == 2)
    {
        if (options.allow_then and !options.allow_then_strict) return true;
        if (tree.data(unwrapTransparent(tree, arguments[0])) == .null_literal) return true;
    }

    if (options.allow_finally and
        property_name != null and
        std.mem.eql(u8, property_name.?, "finally") and
        isPromise(tree, member.object) and
        isAllowedTermination(tree, member.object, options))
    {
        return true;
    }

    if (property_name) |name| {
        if (options.termination_methods.contains(name)) return true;
    }

    return isComputedStringPropertyNamed(tree, member, "catch");
}

fn isPromise(tree: *const ast.Tree, expression_index: ast.NodeIndex) bool {
    const expression = switch (tree.data(unwrapTransparent(tree, expression_index))) {
        .call_expression => |call| call,
        else => return false,
    };
    const member = switch (tree.data(unwrapTransparent(tree, expression.callee))) {
        .member_expression => |member| member,
        else => return false,
    };

    if (memberPropertyIdentifierName(tree, member)) |name| {
        if (std.mem.eql(u8, name, "then") or
            std.mem.eql(u8, name, "catch") or
            std.mem.eql(u8, name, "finally")) return true;
    }

    if (isPromise(tree, member.object)) return true;
    if (!isIdentifierReferenceNamed(tree, member.object, "Promise")) return false;

    const name = memberPropertyIdentifierName(tree, member) orelse return false;
    if (std.mem.eql(u8, name, "withResolvers")) return false;
    return isPromiseStatic(name);
}

fn isPromiseStatic(name: []const u8) bool {
    const statics = [_][]const u8{
        "all",
        "allSettled",
        "any",
        "race",
        "reject",
        "resolve",
    };
    for (statics) |static_name| {
        if (std.mem.eql(u8, name, static_name)) return true;
    }
    return false;
}

fn isMemberCallRootedAt(tree: *const ast.Tree, expression_index: ast.NodeIndex, root_name: []const u8) bool {
    const expression = switch (tree.data(unwrapTransparent(tree, expression_index))) {
        .call_expression => |call| call,
        else => return false,
    };
    const member = switch (tree.data(unwrapTransparent(tree, expression.callee))) {
        .member_expression => |member| member,
        else => return false,
    };

    return isIdentifierReferenceNamed(tree, member.object, root_name) or
        isMemberCallRootedAt(tree, member.object, root_name);
}

fn memberPropertyIdentifierName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;
    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isComputedStringPropertyNamed(tree: *const ast.Tree, member: ast.MemberExpression, name: []const u8) bool {
    if (!member.computed or member.property == .null) return false;
    return switch (tree.data(member.property)) {
        .string_literal => |literal| std.mem.eql(u8, tree.string(literal.value), name),
        else => false,
    };
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
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
