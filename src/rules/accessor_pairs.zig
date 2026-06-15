const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "accessor-pairs";

pub const Options = struct {
    get_without_set: bool = false,
    set_without_get: bool = true,
};

const Accessor = struct {
    name: []const u8,
    static: bool = false,
    get: bool = false,
    get_index: ast.NodeIndex = .null,
    set: bool = false,
    set_index: ast.NodeIndex = .null,
};

pub fn checkObjectExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ObjectExpression,
) Allocator.Error!void {
    try checkObjectExpressionWithOptions(allocator, diagnostics, tree, expression, .{});
}

pub fn checkObjectExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ObjectExpression,
    options: Options,
) Allocator.Error!void {
    var accessors: std.ArrayList(Accessor) = .empty;
    defer accessors.deinit(allocator);

    for (tree.extra(expression.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        if (property.kind != .get and property.kind != .set) continue;

        const name = propertyName(tree, property.key, property.computed) orelse continue;
        try recordAccessor(allocator, &accessors, name, false, property.kind == .get, property.kind == .set, property_index);
    }

    try reportMissingCounterparts(allocator, diagnostics, tree, accessors.items, options);
}

pub fn checkClassBody(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.ClassBody,
) Allocator.Error!void {
    try checkClassBodyWithOptions(allocator, diagnostics, tree, body, .{});
}

pub fn checkClassBodyWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.ClassBody,
    options: Options,
) Allocator.Error!void {
    var accessors: std.ArrayList(Accessor) = .empty;
    defer accessors.deinit(allocator);

    for (tree.extra(body.body)) |member_index| {
        const method = switch (tree.data(member_index)) {
            .method_definition => |method| method,
            else => continue,
        };
        if (method.kind != .get and method.kind != .set) continue;

        const name = propertyName(tree, method.key, method.computed) orelse continue;
        try recordAccessor(allocator, &accessors, name, method.static, method.kind == .get, method.kind == .set, member_index);
    }

    try reportMissingCounterparts(allocator, diagnostics, tree, accessors.items, options);
}

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
) Allocator.Error!void {
    try checkCallExpressionWithOptions(allocator, diagnostics, tree, call, .{});
}

pub fn checkCallExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    options: Options,
) Allocator.Error!void {
    const arguments = tree.extra(call.arguments);

    if (isStaticMemberCall(tree, call.callee, "Object", "defineProperty")) {
        if (arguments.len < 3) return;
        try checkPropertyDescriptor(allocator, diagnostics, tree, arguments[2], arguments[1], options);
        return;
    }

    if (isStaticMemberCall(tree, call.callee, "Object", "defineProperties")) {
        if (arguments.len < 2) return;
        try checkNestedDescriptors(allocator, diagnostics, tree, arguments[1], options);
        return;
    }

    if (isStaticMemberCall(tree, call.callee, "Object", "create")) {
        if (arguments.len < 2) return;
        try checkNestedDescriptors(allocator, diagnostics, tree, arguments[1], options);
    }
}

fn checkNestedDescriptors(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    descriptors_index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const descriptors = switch (tree.data(descriptors_index)) {
        .object_expression => |object| object,
        else => return,
    };

    for (tree.extra(descriptors.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        if (property.value == .null) continue;
        try checkPropertyDescriptor(allocator, diagnostics, tree, property.value, property.key, options);
    }
}

fn checkPropertyDescriptor(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    descriptor_index: ast.NodeIndex,
    report_index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const descriptor = switch (tree.data(descriptor_index)) {
        .object_expression => |object| object,
        else => return,
    };

    var has_get = false;
    var get_index: ast.NodeIndex = .null;
    var has_set = false;
    var set_index: ast.NodeIndex = .null;

    for (tree.extra(descriptor.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };

        if (propertyKeyEquals(tree, property, "get")) {
            has_get = true;
            get_index = property_index;
        } else if (propertyKeyEquals(tree, property, "set")) {
            has_set = true;
            set_index = property_index;
        }
    }

    if (options.set_without_get and !has_get and set_index != .null) {
        try addSetterDiagnostic(allocator, diagnostics, tree, report_index);
    }
    if (options.get_without_set and has_get and !has_set and get_index != .null) {
        try addGetterDiagnostic(allocator, diagnostics, tree, report_index);
    }
}

fn recordAccessor(
    allocator: Allocator,
    accessors: *std.ArrayList(Accessor),
    name: []const u8,
    static: bool,
    is_get: bool,
    is_set: bool,
    index: ast.NodeIndex,
) Allocator.Error!void {
    for (accessors.items) |*accessor| {
        if (accessor.static != static) continue;
        if (!std.mem.eql(u8, accessor.name, name)) continue;

        accessor.get = accessor.get or is_get;
        if (is_get) accessor.get_index = index;
        if (is_set) {
            accessor.set = true;
            accessor.set_index = index;
        }
        return;
    }

    try accessors.append(allocator, .{
        .name = name,
        .static = static,
        .get = is_get,
        .get_index = if (is_get) index else .null,
        .set = is_set,
        .set_index = if (is_set) index else .null,
    });
}

fn reportMissingCounterparts(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    accessors: []const Accessor,
    options: Options,
) Allocator.Error!void {
    for (accessors) |accessor| {
        if (options.set_without_get and accessor.set and !accessor.get) {
            try addSetterDiagnostic(allocator, diagnostics, tree, accessor.set_index);
        }
        if (options.get_without_set and accessor.get and !accessor.set) {
            try addGetterDiagnostic(allocator, diagnostics, tree, accessor.get_index);
        }
    }
}

fn addSetterDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Setter must be accompanied by a getter.",
        tree.span(index),
    );
}

fn addGetterDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Getter must be accompanied by a setter.",
        tree.span(index),
    );
}

fn propertyName(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (key == .null) return null;

    return switch (tree.data(key)) {
        .identifier_name => |identifier| if (computed) null else tree.string(identifier.name),
        .private_identifier => |identifier| if (computed) null else tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        .identifier_reference => if (computed) sourceSlice(tree, key) else null,
        .template_literal => |literal| templateStringValue(tree, literal) orelse if (computed) sourceSlice(tree, key) else null,
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

fn sourceSlice(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start >= end or end > tree.source.len) return null;

    return tree.source[start..end];
}

fn propertyKeyEquals(tree: *const ast.Tree, property: ast.ObjectProperty, name: []const u8) bool {
    if (property.computed) return false;
    if (property.key == .null) return false;

    return switch (tree.data(property.key)) {
        .identifier_name => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        .string_literal => |literal| std.mem.eql(u8, tree.string(literal.value), name),
        else => false,
    };
}

fn isStaticMemberCall(tree: *const ast.Tree, callee: ast.NodeIndex, object_name: []const u8, property_name: []const u8) bool {
    const member = switch (tree.data(unwrapTransparent(tree, callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;

    return isIdentifierReferenceNamed(tree, member.object, object_name) and
        isIdentifierNameNamed(tree, member.property, property_name);
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn isIdentifierNameNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
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
