const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "dot-notation";

pub const Options = struct {
    rule_id: []const u8 = id,
    severity: core.Severity = .warning,
    allow_keywords: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, member, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!member.computed or member.property == .null) return;

    const property_name = staticPropertyName(tree, member.property) orelse return;
    if (!isAsciiIdentifierName(property_name)) return;
    if (!options.allow_keywords and isKeyword(property_name)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        options.severity,
        options.rule_id,
        tree.span(index),
        "['{s}'] is better written in dot notation.",
        .{property_name},
    );
}

fn staticPropertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
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

fn isAsciiIdentifierName(name: []const u8) bool {
    if (name.len == 0) return false;
    if (!isIdentifierStart(name[0])) return false;

    for (name[1..]) |char| {
        if (!isIdentifierPart(char)) return false;
    }
    return true;
}

fn isIdentifierStart(char: u8) bool {
    return std.ascii.isAlphabetic(char) or char == '_' or char == '$';
}

fn isIdentifierPart(char: u8) bool {
    return isIdentifierStart(char) or std.ascii.isDigit(char);
}

fn isKeyword(name: []const u8) bool {
    const keywords = [_][]const u8{
        "abstract",
        "boolean",
        "break",
        "byte",
        "case",
        "catch",
        "char",
        "class",
        "const",
        "continue",
        "debugger",
        "default",
        "delete",
        "do",
        "double",
        "else",
        "enum",
        "export",
        "extends",
        "false",
        "final",
        "finally",
        "float",
        "for",
        "function",
        "goto",
        "if",
        "implements",
        "import",
        "in",
        "instanceof",
        "int",
        "interface",
        "long",
        "native",
        "new",
        "null",
        "package",
        "private",
        "protected",
        "public",
        "return",
        "short",
        "static",
        "super",
        "switch",
        "synchronized",
        "this",
        "throw",
        "throws",
        "transient",
        "true",
        "try",
        "typeof",
        "var",
        "void",
        "volatile",
        "while",
        "with",
    };

    for (keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) return true;
    }
    return false;
}
