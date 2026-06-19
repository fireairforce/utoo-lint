const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "id-denylist";

pub const State = struct {
    reported_spans: std.ArrayList(ast.Span) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.reported_spans.deinit(allocator);
    }
};

pub fn checkNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    data: ast.NodeData,
    index: ast.NodeIndex,
    path: *const traverser.NodePath,
    state: *State,
    names: *const core.IdDenylistNames,
) Allocator.Error!void {
    if (names.count == 0) return;

    const identifier = identifierName(tree, data) orelse return;
    if (!names.contains(identifier.name)) return;
    if (!shouldCheck(tree, index, path)) return;

    try report(allocator, diagnostics, tree, index, identifier, state);
}

const Identifier = struct {
    name: []const u8,
    private: bool = false,
};

fn identifierName(tree: *const ast.Tree, data: ast.NodeData) ?Identifier {
    return switch (data) {
        .identifier_reference => |identifier| .{ .name = tree.string(identifier.name) },
        .binding_identifier => |identifier| .{ .name = tree.string(identifier.name) },
        .identifier_name => |identifier| .{ .name = tree.string(identifier.name) },
        .private_identifier => |identifier| .{ .name = tree.string(identifier.name), .private = true },
        else => null,
    };
}

fn shouldCheck(tree: *const ast.Tree, index: ast.NodeIndex, path: *const traverser.NodePath) bool {
    const parent_index = path.parent() orelse return true;
    const parent_data = tree.data(parent_index);

    switch (parent_data) {
        .member_expression => |member| {
            if (member.property == index and !member.computed) {
                return isAssignmentTarget(tree, parent_index, path);
            }
        },
        .call_expression,
        .new_expression,
        => return false,
        .binding_property => |property| {
            if (!property.computed and property.key == index and isObjectPatternParent(tree, path.ancestor(2))) {
                return false;
            }
        },
        .import_specifier => |specifier| {
            if (specifier.imported == index and specifier.imported != specifier.local) return false;
        },
        .export_specifier => |specifier| {
            if (specifier.local == index and specifier.local != specifier.exported and isReExport(tree, path.ancestor(2))) return false;
        },
        else => {},
    }

    return true;
}

fn isAssignmentTarget(tree: *const ast.Tree, index: ast.NodeIndex, path: *const traverser.NodePath) bool {
    const parent = path.ancestor(2) orelse return false;
    return switch (tree.data(parent)) {
        .assignment_expression => |assignment| assignment.left == index,
        .array_pattern => true,
        .binding_rest_element => true,
        .assignment_pattern => |pattern| pattern.left == index,
        .binding_property => |property| property.value == index and isObjectPatternParent(tree, path.ancestor(3)),
        else => false,
    };
}

fn isObjectPatternParent(tree: *const ast.Tree, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    return switch (tree.data(parent)) {
        .object_pattern => true,
        else => false,
    };
}

fn isReExport(tree: *const ast.Tree, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    return switch (tree.data(parent)) {
        .export_named_declaration => |declaration| declaration.source != .null,
        else => false,
    };
}

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    identifier: Identifier,
    state: *State,
) Allocator.Error!void {
    const span = tree.span(index);
    for (state.reported_spans.items) |reported| {
        if (reported.start == span.start and reported.end == span.end) return;
    }
    try state.reported_spans.append(allocator, span);

    if (identifier.private) {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            span,
            "Identifier '#{s}' is restricted.",
            .{identifier.name},
        );
    } else {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            span,
            "Identifier '{s}' is restricted.",
            .{identifier.name},
        );
    }
}
