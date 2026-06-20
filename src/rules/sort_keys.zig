const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "sort-keys";

pub const Options = struct {
    order: core.SortKeysOrder = .asc,
    case_sensitive: bool = true,
    natural: bool = false,
    min_keys: usize = 2,
    allow_line_separated_groups: bool = false,
};

const PropertyName = struct {
    value: []const u8,
    owned: bool = false,
};

pub fn checkObjectExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ObjectExpression,
    options: Options,
) Allocator.Error!void {
    var group_count: usize = 0;
    var previous_name: ?PropertyName = null;
    var previous_node: ast.NodeIndex = .null;
    defer if (previous_name) |name| {
        if (name.owned) allocator.free(name.value);
    };

    for (tree.extra(expression.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => {
                if (previous_name) |name| {
                    if (name.owned) allocator.free(name.value);
                }
                previous_name = null;
                previous_node = .null;
                group_count = 0;
                continue;
            },
        };

        const name = try propertyName(allocator, tree, property) orelse {
            if (previous_name) |old| {
                if (old.owned) allocator.free(old.value);
            }
            previous_name = null;
            previous_node = .null;
            group_count = 0;
            continue;
        };
        errdefer if (name.owned) allocator.free(name.value);

        if (options.allow_line_separated_groups and propertiesAreSeparated(tree, previous_node, property_index)) {
            if (previous_name) |old| {
                if (old.owned) allocator.free(old.value);
            }
            previous_name = name;
            previous_node = property_index;
            group_count = 1;
            continue;
        }

        group_count += 1;
        if (group_count >= options.min_keys) {
            if (previous_name) |previous| {
                if (!keysAreSorted(previous.value, name.value, options)) {
                    try addDiagnostic(allocator, diagnostics, tree, property_index, previous.value, name.value, options);
                }
            }
        }

        if (previous_name) |old| {
            if (old.owned) allocator.free(old.value);
        }
        previous_name = name;
        previous_node = property_index;
    }
}

fn keysAreSorted(previous: []const u8, current: []const u8, options: Options) bool {
    const comparison = compareNames(previous, current, options);
    return switch (options.order) {
        .asc => comparison <= 0,
        .desc => comparison >= 0,
    };
}

fn compareNames(left: []const u8, right: []const u8, options: Options) i8 {
    if (options.natural) return naturalCompare(left, right, options.case_sensitive);

    const min_len = @min(left.len, right.len);
    for (0..min_len) |index| {
        const left_char = normalizeChar(left[index], options.case_sensitive);
        const right_char = normalizeChar(right[index], options.case_sensitive);
        if (left_char < right_char) return -1;
        if (left_char > right_char) return 1;
    }
    if (left.len < right.len) return -1;
    if (left.len > right.len) return 1;
    return 0;
}

fn naturalCompare(left: []const u8, right: []const u8, case_sensitive: bool) i8 {
    var left_index: usize = 0;
    var right_index: usize = 0;

    while (left_index < left.len and right_index < right.len) {
        if (std.ascii.isDigit(left[left_index]) and std.ascii.isDigit(right[right_index])) {
            const left_number = numberSlice(left, &left_index);
            const right_number = numberSlice(right, &right_index);
            const number_order = compareNumberSlices(left_number, right_number);
            if (number_order != 0) return number_order;
            continue;
        }

        const left_char = normalizeChar(left[left_index], case_sensitive);
        const right_char = normalizeChar(right[right_index], case_sensitive);
        if (left_char < right_char) return -1;
        if (left_char > right_char) return 1;
        left_index += 1;
        right_index += 1;
    }

    if (left_index < left.len) return 1;
    if (right_index < right.len) return -1;
    return 0;
}

fn numberSlice(value: []const u8, index: *usize) []const u8 {
    const start = index.*;
    while (index.* < value.len and std.ascii.isDigit(value[index.*])) {
        index.* += 1;
    }
    return value[start..index.*];
}

fn compareNumberSlices(left: []const u8, right: []const u8) i8 {
    const trimmed_left = trimLeadingZeroes(left);
    const trimmed_right = trimLeadingZeroes(right);
    if (trimmed_left.len < trimmed_right.len) return -1;
    if (trimmed_left.len > trimmed_right.len) return 1;
    const lexical = std.mem.order(u8, trimmed_left, trimmed_right);
    if (lexical == .lt) return -1;
    if (lexical == .gt) return 1;
    if (left.len < right.len) return -1;
    if (left.len > right.len) return 1;
    return 0;
}

fn trimLeadingZeroes(value: []const u8) []const u8 {
    var index: usize = 0;
    while (index + 1 < value.len and value[index] == '0') {
        index += 1;
    }
    return value[index..];
}

fn normalizeChar(char: u8, case_sensitive: bool) u8 {
    return if (case_sensitive) char else std.ascii.toLower(char);
}

fn propertiesAreSeparated(tree: *const ast.Tree, previous: ast.NodeIndex, current: ast.NodeIndex) bool {
    if (previous == .null or current == .null) return false;
    const previous_span = tree.span(previous);
    const current_span = tree.span(current);
    if (previous_span.end >= current_span.start) return false;

    const between = tree.source[previous_span.end..current_span.start];
    var newline_count: usize = 0;
    for (between) |char| {
        if (char == '\n') {
            newline_count += 1;
            if (newline_count >= 2) return true;
        } else if (char != '\r' and char != ' ' and char != '\t' and char != ',') {
            newline_count = 0;
        }
    }
    return false;
}

fn propertyName(allocator: Allocator, tree: *const ast.Tree, property: ast.ObjectProperty) Allocator.Error!?PropertyName {
    if (property.key == .null) return null;
    if (isPrototypeSetter(tree, property)) return null;

    const key = unwrapTransparent(tree, property.key);
    return switch (tree.data(key)) {
        .identifier_name => |identifier| if (property.computed) null else .{ .value = tree.string(identifier.name) },
        .string_literal => |literal| .{ .value = tree.string(literal.value) },
        .numeric_literal => |literal| .{ .value = try numericPropertyName(allocator, tree, literal), .owned = true },
        .template_literal => |literal| templatePropertyName(tree, literal),
        else => null,
    };
}

fn isPrototypeSetter(tree: *const ast.Tree, property: ast.ObjectProperty) bool {
    if (property.computed or property.kind != .init or property.method) return false;
    const key = unwrapTransparent(tree, property.key);
    const name = switch (tree.data(key)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => return false,
    };
    return std.mem.eql(u8, name, "__proto__");
}

fn numericPropertyName(allocator: Allocator, tree: *const ast.Tree, literal: ast.NumericLiteral) Allocator.Error![]const u8 {
    const value = literal.value(tree);
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}

fn templatePropertyName(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?PropertyName {
    if (tree.extra(literal.expressions).len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len != 1) return null;

    return switch (tree.data(quasis[0])) {
        .template_element => |element| .{ .value = tree.string(element.cooked) },
        else => null,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;

    while (current != .null) {
        switch (tree.data(current)) {
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }

    return current;
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    previous: []const u8,
    current: []const u8,
    options: Options,
) Allocator.Error!void {
    const order = switch (options.order) {
        .asc => "ascending",
        .desc => "descending",
    };
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Expected object keys to be in {s} order. '{s}' should be before '{s}'.",
        .{ order, current, previous },
    );
}
