const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-empty-object-type";

pub const Options = struct {
    allow_interfaces: core.TypescriptEslintNoEmptyObjectTypeAllowInterfaces = .never,
    allow_object_types: core.TypescriptEslintNoEmptyObjectTypeAllowObjectTypes = .never,
    allow_with_name: core.TypescriptEslintNoEmptyObjectTypeAllowWithName = .{},
};

pub fn checkInterfaceDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.TSInterfaceDeclaration,
    options: Options,
) Allocator.Error!void {
    if (options.allow_interfaces == .always) return;

    const body = switch (tree.data(declaration.body)) {
        .ts_interface_body => |interface_body| interface_body,
        else => return,
    };
    if (body.body.len != 0 or declaration.extends.len > 1) return;
    if (declaration.extends.len == 1 and options.allow_interfaces == .with_single_extends) return;

    const name = bindingIdentifierName(tree, declaration.id) orelse return;
    if (nameMatches(options.allow_with_name, name)) return;

    const message = if (declaration.extends.len == 1)
        "An interface declaring no members is equivalent to its supertype."
    else
        "An empty interface declaration allows any non-nullish value. Use `object` or `unknown` instead.";
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        tree.span(declaration.id),
    );
}

pub fn checkTypeLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    type_literal: ast.TSTypeLiteral,
    index: ast.NodeIndex,
    ctx: *const traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (options.allow_object_types == .always or type_literal.members.len != 0) return;

    const parent_index = ctx.path.parent();
    if (parent_index) |parent| {
        if (tree.data(parent) == .ts_intersection_type) return;
        if (tree.data(parent) == .ts_type_alias_declaration) {
            const declaration = tree.data(parent).ts_type_alias_declaration;
            if (declaration.type_annotation == index) {
                const name = bindingIdentifierName(tree, declaration.id) orelse return;
                if (nameMatches(options.allow_with_name, name)) return;
            }
        }
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "The `{}` (empty object) type allows any non-nullish value. Use `object` or `unknown` instead.",
        tree.span(index),
    );
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn nameMatches(pattern_option: core.TypescriptEslintNoEmptyObjectTypeAllowWithName, name: []const u8) bool {
    const pattern = pattern_option.pattern() orelse return false;

    var start: usize = 0;
    while (start <= pattern.len) {
        const remainder = pattern[start..];
        const separator = std.mem.indexOfScalar(u8, remainder, '|');
        const end = if (separator) |offset| start + offset else pattern.len;
        if (matchesAlternative(name, pattern[start..end])) return true;
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
