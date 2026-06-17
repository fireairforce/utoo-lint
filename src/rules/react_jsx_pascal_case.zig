const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/jsx-pascal-case";

pub const Options = struct {
    allow_all_caps: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, opening, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (isDomComponent(tree, opening.name)) return;

    const invalid_name = invalidNamePart(tree, opening.name, options) orelse return;
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "Imported JSX component {s} must be in PascalCase or SCREAMING_SNAKE_CASE",
        .{invalid_name},
    );
}

fn isDomComponent(tree: *const ast.Tree, name_index: ast.NodeIndex) bool {
    const first = firstNamePart(tree, name_index) orelse return false;
    return first.len > 0 and first[0] >= 'a' and first[0] <= 'z';
}

fn firstNamePart(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        .jsx_namespaced_name => |name| firstNamePart(tree, name.namespace),
        .jsx_member_expression => |member| firstNamePart(tree, member.object),
        else => null,
    };
}

fn invalidNamePart(tree: *const ast.Tree, name_index: ast.NodeIndex, options: Options) ?[]const u8 {
    switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| {
            const name = tree.string(identifier.name);
            if (name.len == 1) return null;
            return if (isPascalCase(name) or (options.allow_all_caps and isAllCaps(name))) null else name;
        },
        .jsx_namespaced_name => |name| {
            if (invalidNamePart(tree, name.namespace, options)) |invalid| return invalid;
            return invalidNamePart(tree, name.name, options);
        },
        .jsx_member_expression => |member| {
            if (invalidNamePart(tree, member.object, options)) |invalid| return invalid;
            return invalidNamePart(tree, member.property, options);
        },
        else => return null,
    }
}

fn isPascalCase(name: []const u8) bool {
    if (name.len == 0 or !isUpper(name[0])) return false;

    var has_lower_or_digit = false;
    for (name[1..]) |byte| {
        if (isLower(byte) or isDigit(byte)) {
            has_lower_or_digit = true;
        } else if (!isUpper(byte)) {
            return false;
        }
    }
    return has_lower_or_digit;
}

fn isAllCaps(name: []const u8) bool {
    if (name.len == 0) return false;
    if (!isUpper(name[0]) and !isDigit(name[0])) return false;
    if (name.len == 1) return true;

    for (name[1 .. name.len - 1]) |byte| {
        if (!isUpper(byte) and !isDigit(byte) and byte != '_') return false;
    }

    const last = name[name.len - 1];
    return isUpper(last) or isDigit(last);
}

fn isUpper(byte: u8) bool {
    return byte >= 'A' and byte <= 'Z';
}

fn isLower(byte: u8) bool {
    return byte >= 'a' and byte <= 'z';
}

fn isDigit(byte: u8) bool {
    return byte >= '0' and byte <= '9';
}
