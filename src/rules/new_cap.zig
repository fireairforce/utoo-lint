const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "new-cap";

pub const Options = struct {
    new_is_cap: bool = true,
    cap_is_new: bool = true,
    properties: bool = true,
    new_is_cap_exceptions: core.NewCapExceptionNames = .{},
    cap_is_new_exceptions: core.NewCapExceptionNames = .{},
    new_is_cap_exception_pattern: core.NewCapExceptionPattern = .{},
    cap_is_new_exception_pattern: core.NewCapExceptionPattern = .{},
};

pub fn checkNewExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NewExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkNewExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkNewExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NewExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!options.new_is_cap) return;

    const name = constructorName(tree, expression.callee, options) orelse return;
    if (isNewIsCapException(name, options)) return;
    if (nameCase(name) != .lower) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "A constructor name should not start with a lowercase letter.",
        tree.span(index),
    );
}

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.CallExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkCallExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkCallExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.CallExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!options.cap_is_new) return;

    const callee = unwrapTransparent(tree, expression.callee);
    const name = constructorName(tree, callee, options) orelse return;
    if (isCapIsNewException(name, options)) return;
    if (nameCase(name) != .upper) return;
    if (isAllowedCallableBuiltin(tree, callee, name)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "A function with a name starting with an uppercase letter should only be used as a constructor.",
        tree.span(index),
    );
}

fn constructorName(tree: *const ast.Tree, index: ast.NodeIndex, options: Options) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .member_expression => |member| if (options.properties) propertyName(tree, member) else null,
        else => null,
    };
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

fn isAllowedCallableBuiltin(tree: *const ast.Tree, callee: ast.NodeIndex, name: []const u8) bool {
    if (tree.data(callee) != .identifier_reference) return false;

    const builtins = [_][]const u8{
        "Array",
        "BigInt",
        "Boolean",
        "Date",
        "Error",
        "Number",
        "Object",
        "RegExp",
        "String",
        "Symbol",
    };

    for (builtins) |builtin| {
        if (std.mem.eql(u8, name, builtin)) return true;
    }

    return false;
}

fn isNewIsCapException(name: []const u8, options: Options) bool {
    if (options.new_is_cap_exceptions.contains(name)) return true;
    return matchesPatternOption(name, options.new_is_cap_exception_pattern);
}

fn isCapIsNewException(name: []const u8, options: Options) bool {
    if (options.cap_is_new_exceptions.contains(name)) return true;
    return matchesPatternOption(name, options.cap_is_new_exception_pattern);
}

fn matchesPatternOption(name: []const u8, pattern: core.NewCapExceptionPattern) bool {
    const custom_pattern = pattern.pattern() orelse return false;
    return matchesPattern(name, custom_pattern);
}

fn matchesPattern(value: []const u8, pattern: []const u8) bool {
    var start: usize = 0;
    while (start <= pattern.len) {
        const remainder = pattern[start..];
        const separator = std.mem.indexOfScalar(u8, remainder, '|');
        const end = if (separator) |offset| start + offset else pattern.len;
        if (matchesAlternative(value, pattern[start..end])) return true;
        if (separator == null) break;
        start = end + 1;
    }
    return false;
}

fn matchesAlternative(value: []const u8, pattern: []const u8) bool {
    if (pattern.len == 0) return false;

    const anchored_start = std.mem.startsWith(u8, pattern, "^");
    const anchored_end = std.mem.endsWith(u8, pattern, "$");
    const body_start: usize = if (anchored_start) 1 else 0;
    const body_end = if (anchored_end and pattern.len > body_start) pattern.len - 1 else pattern.len;
    const body = pattern[body_start..body_end];

    if (std.mem.indexOf(u8, body, ".*") != null) {
        return matchesWildcardSequence(value, body, anchored_start, anchored_end);
    }
    if (anchored_start and anchored_end) return std.mem.eql(u8, value, body);
    if (anchored_start) return std.mem.startsWith(u8, value, body);
    if (anchored_end) return std.mem.endsWith(u8, value, body);
    return std.mem.indexOf(u8, value, body) != null;
}

fn matchesWildcardSequence(value: []const u8, pattern: []const u8, anchored_start: bool, anchored_end: bool) bool {
    var value_offset: usize = 0;
    var pattern_offset: usize = 0;
    var part_index: usize = 0;

    while (pattern_offset <= pattern.len) : (part_index += 1) {
        const remainder = pattern[pattern_offset..];
        const wildcard = std.mem.indexOf(u8, remainder, ".*");
        const part_end = if (wildcard) |offset| pattern_offset + offset else pattern.len;
        const part = pattern[pattern_offset..part_end];

        if (part.len > 0) {
            if (part_index == 0 and anchored_start) {
                if (!std.mem.startsWith(u8, value[value_offset..], part)) return false;
                value_offset += part.len;
            } else {
                const found = std.mem.indexOf(u8, value[value_offset..], part) orelse return false;
                value_offset += found + part.len;
            }
        }

        if (wildcard == null) break;
        pattern_offset = part_end + 2;
    }

    if (!anchored_end) return true;
    const suffix_start = lastWildcardPartStart(pattern);
    return std.mem.endsWith(u8, value, pattern[suffix_start..]);
}

fn lastWildcardPartStart(pattern: []const u8) usize {
    var offset: usize = 0;
    var start: usize = 0;
    while (offset < pattern.len) {
        const wildcard = std.mem.indexOf(u8, pattern[offset..], ".*") orelse break;
        start = offset + wildcard + 2;
        offset = start;
    }
    return start;
}

const NameCase = enum {
    upper,
    lower,
    other,
};

fn nameCase(name: []const u8) NameCase {
    if (name.len == 0) return .other;
    if (std.ascii.isUpper(name[0])) return .upper;
    if (std.ascii.isLower(name[0])) return .lower;
    return .other;
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
