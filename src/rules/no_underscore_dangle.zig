const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-underscore-dangle";

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
    if (member.computed) return;

    const name = propertyName(tree, member) orelse return;
    try checkName(allocator, diagnostics, tree, member.property, name, true);
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
