const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-underscore-dangle";

pub const Options = struct {
    allow_after_this: bool = false,
    allow_after_super: bool = false,
    allow_after_this_constructor: bool = false,
};

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
) Allocator.Error!void {
    const name = bindingName(tree, declarator.id) orelse return;
    try checkName(allocator, diagnostics, tree, declarator.id, name, false);
}

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
) Allocator.Error!void {
    if (function.id == .null) return;

    const name = bindingName(tree, function.id) orelse return;
    try checkName(allocator, diagnostics, tree, function.id, name, false);
}

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
) Allocator.Error!void {
    if (class.id == .null) return;

    const name = bindingName(tree, class.id) orelse return;
    try checkName(allocator, diagnostics, tree, class.id, name, false);
}

pub fn checkMemberExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
) Allocator.Error!void {
    return checkMemberExpressionWithOptions(allocator, diagnostics, tree, member, .{});
}

pub fn checkMemberExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    options: Options,
) Allocator.Error!void {
    if (member.computed) return;

    const name = propertyName(tree, member) orelse return;
    if (isAllowedMemberAccess(tree, member, options)) return;
    try checkName(allocator, diagnostics, tree, member.property, name, true);
}

fn isAllowedMemberAccess(tree: *const ast.Tree, member: ast.MemberExpression, options: Options) bool {
    if (options.allow_after_this and isThisExpression(tree, member.object)) return true;
    if (options.allow_after_super and isSuperExpression(tree, member.object)) return true;
    if (options.allow_after_this_constructor and isThisConstructorExpression(tree, member.object)) return true;
    return false;
}

fn checkName(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    name: []const u8,
    allow_proto: bool,
) Allocator.Error!void {
    if (!hasDanglingUnderscore(name)) return;
    if (isAllowedName(name, allow_proto)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(node),
        "Unexpected dangling '_' in '{s}'.",
        .{name},
    );
}

fn hasDanglingUnderscore(name: []const u8) bool {
    if (name.len == 0) return false;
    return name[0] == '_' or name[name.len - 1] == '_';
}

fn isAllowedName(name: []const u8, allow_proto: bool) bool {
    if (std.mem.eql(u8, name, "_")) return true;
    if (std.mem.eql(u8, name, "__dirname")) return true;
    if (std.mem.eql(u8, name, "__filename")) return true;
    return allow_proto and std.mem.eql(u8, name, "__proto__");
}

fn bindingName(tree: *const ast.Tree, node: ast.NodeIndex) ?[]const u8 {
    if (node == .null) return null;

    return switch (tree.data(node)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isThisExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .this_expression => true,
        else => false,
    };
}

fn isSuperExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .super => true,
        else => false,
    };
}

fn isThisConstructorExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const unwrapped = unwrapTransparent(tree, index);
    return switch (tree.data(unwrapped)) {
        .member_expression => |member| isThisExpression(tree, member.object) and isPropertyNamed(tree, member, "constructor"),
        else => false,
    };
}

fn isPropertyNamed(tree: *const ast.Tree, member: ast.MemberExpression, expected: []const u8) bool {
    const name = propertyName(tree, member) orelse return false;
    return std.mem.eql(u8, name, expected);
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
