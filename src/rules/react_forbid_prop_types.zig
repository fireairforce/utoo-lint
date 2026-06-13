const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/forbid-prop-types";

const forbidden = [_][]const u8{ "any", "array", "object" };

const ObjectBinding = struct {
    name: []const u8,
    value: ast.NodeIndex,
};

pub const State = struct {
    prop_types_package_name: ?[]const u8 = null,
    react_package_name: ?[]const u8 = null,
    is_foreign_prop_types_package: bool = false,
    object_bindings: std.ArrayList(ObjectBinding) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.object_bindings.deinit(allocator);
        self.* = .{};
    }
};

pub fn collectProgram(
    allocator: Allocator,
    tree: *const ast.Tree,
    program: ast.Program,
    state: *State,
) Allocator.Error!void {
    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        scanImportDeclaration(tree, declaration, state);
    }

    _ = allocator;
}

pub fn collectVariableDeclarator(
    allocator: Allocator,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    state: *State,
) Allocator.Error!void {
    if (declarator.init == .null) return;
    switch (tree.data(unwrapTransparent(tree, declarator.init))) {
        .object_expression => {},
        else => return,
    }

    const name = bindingIdentifierName(tree, declarator.id) orelse return;
    for (state.object_bindings.items) |binding| {
        if (std.mem.eql(u8, binding.name, name)) return;
    }
    try state.object_bindings.append(allocator, .{ .name = name, .value = declarator.init });
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    state: State,
) Allocator.Error!void {
    if (!isPropTypesKey(tree, property.key, property.computed)) return;
    try checkNode(allocator, diagnostics, tree, property.value, state);
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    state: State,
) Allocator.Error!void {
    const member = switch (tree.data(unwrapTransparent(tree, expression.left))) {
        .member_expression => |member| member,
        else => return,
    };
    if (!isPropTypesKey(tree, member.property, member.computed)) return;
    try checkNode(allocator, diagnostics, tree, expression.right, state);
}

pub fn checkObjectExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    object: ast.ObjectExpression,
    state: State,
) Allocator.Error!void {
    for (tree.extra(object.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        if (!isPropTypesKey(tree, property.key, property.computed)) continue;
        try checkNode(allocator, diagnostics, tree, property.value, state);
    }
}

pub fn checkMethodDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    method: ast.MethodDefinition,
    state: State,
) Allocator.Error!void {
    if (!isPropTypesKey(tree, method.key, method.computed)) return;
    const argument = returnArgument(tree, method.value) orelse return;
    try checkNode(allocator, diagnostics, tree, argument, state);
}

fn scanImportDeclaration(tree: *const ast.Tree, declaration: ast.ImportDeclaration, state: *State) void {
    if (declaration.import_kind == .type) return;
    const source = stringLiteralValue(tree, declaration.source) orelse return;
    const specifiers = tree.extra(declaration.specifiers);

    if (std.mem.eql(u8, source, "prop-types")) {
        if (specifiers.len > 0) {
            state.prop_types_package_name = importSpecifierLocalName(tree, specifiers[0]);
        }
        return;
    }

    if (std.mem.eql(u8, source, "react")) {
        if (specifiers.len > 0) {
            state.react_package_name = importSpecifierLocalName(tree, specifiers[0]);
        }
        for (specifiers) |specifier_index| {
            const specifier = switch (tree.data(specifier_index)) {
                .import_specifier => |specifier| specifier,
                else => continue,
            };
            const imported = propertyName(tree, specifier.imported, false) orelse continue;
            if (std.mem.eql(u8, imported, "PropTypes")) {
                state.prop_types_package_name = bindingIdentifierName(tree, specifier.local);
            }
        }
        return;
    }

    for (specifiers) |specifier_index| {
        const local = importSpecifierLocalName(tree, specifier_index) orelse continue;
        if (std.mem.eql(u8, local, "PropTypes")) {
            state.is_foreign_prop_types_package = true;
            return;
        }
    }
}

fn checkNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    state: State,
) Allocator.Error!void {
    if (node == .null) return;
    const current = unwrapTransparent(tree, node);
    switch (tree.data(current)) {
        .object_expression => |object| try checkProperties(allocator, diagnostics, tree, object.properties, state),
        .identifier_reference => |identifier| {
            const name = tree.string(identifier.name);
            if (objectBinding(state, name)) |value| {
                try checkNode(allocator, diagnostics, tree, value, state);
            }
        },
        .call_expression => |call| try checkCallExpressionValue(allocator, diagnostics, tree, call, state),
        else => {},
    }
}

fn checkProperties(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    properties: ast.IndexRange,
    state: State,
) Allocator.Error!void {
    for (tree.extra(properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        try checkPropValue(allocator, diagnostics, tree, property.value, property_index, state);
    }
}

fn checkPropValue(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    value_index: ast.NodeIndex,
    diagnostic_node: ast.NodeIndex,
    state: State,
) Allocator.Error!void {
    var value = stripIsRequired(tree, value_index);

    if (callExpression(tree, value)) |call| {
        if (!isPropTypesPackage(tree, call.callee, state)) return;
        for (tree.extra(call.arguments)) |argument| {
            const name = propTypeTargetName(tree, argument) orelse continue;
            try reportIfForbidden(allocator, diagnostics, tree, diagnostic_node, name);
        }
        try checkCallExpressionValue(allocator, diagnostics, tree, call, state);
        value = call.callee;
    }

    if (!isPropTypesPackage(tree, value, state)) return;
    const target = propTypeTargetName(tree, value) orelse return;
    try reportIfForbidden(allocator, diagnostics, tree, diagnostic_node, target);
}

fn checkCallExpressionValue(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    state: State,
) Allocator.Error!void {
    const callee_name = propTypeTargetName(tree, call.callee) orelse identifierReferenceName(tree, call.callee) orelse return;
    const arguments = tree.extra(call.arguments);

    if (std.mem.eql(u8, callee_name, "shape")) {
        if (arguments.len > 0) try checkNode(allocator, diagnostics, tree, arguments[0], state);
    }
}

fn stripIsRequired(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    const member = switch (tree.data(unwrapTransparent(tree, index))) {
        .member_expression => |member| member,
        else => return index,
    };
    if (member.computed) return index;
    const property = propertyName(tree, member.property, false) orelse return index;
    if (!std.mem.eql(u8, property, "isRequired")) return index;
    return member.object;
}

fn isPropTypesPackage(tree: *const ast.Tree, node: ast.NodeIndex, state: State) bool {
    const current = unwrapTransparent(tree, node);
    if (identifierReferenceName(tree, current)) |name| {
        if (state.prop_types_package_name) |package_name| {
            return std.mem.eql(u8, name, package_name);
        }
        return !state.is_foreign_prop_types_package;
    }

    const member = switch (tree.data(current)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;

    const object = unwrapTransparent(tree, member.object);
    if (identifierReferenceName(tree, object)) |name| {
        if (state.prop_types_package_name) |package_name| {
            if (std.mem.eql(u8, name, package_name)) return true;
        }
        if (state.react_package_name) |react_name| {
            if (std.mem.eql(u8, name, react_name)) return true;
        }
        return !state.is_foreign_prop_types_package;
    }

    if (tree.data(object) == .member_expression) {
        return !state.is_foreign_prop_types_package;
    }
    return false;
}

fn propTypeTargetName(tree: *const ast.Tree, node: ast.NodeIndex) ?[]const u8 {
    const current = unwrapTransparent(tree, node);
    const member = switch (tree.data(current)) {
        .member_expression => |member| member,
        else => return identifierReferenceName(tree, current),
    };
    if (member.computed) return null;
    return propertyName(tree, member.property, false);
}

fn reportIfForbidden(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    target: []const u8,
) Allocator.Error!void {
    for (forbidden) |name| {
        if (!std.mem.eql(u8, name, target)) continue;
        return core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(node),
            "Prop type \"{s}\" is forbidden",
            .{target},
        );
    }
}

fn objectBinding(state: State, name: []const u8) ?ast.NodeIndex {
    for (state.object_bindings.items) |binding| {
        if (std.mem.eql(u8, binding.name, name)) return binding.value;
    }
    return null;
}

fn returnArgument(tree: *const ast.Tree, function_index: ast.NodeIndex) ?ast.NodeIndex {
    const function = switch (tree.data(unwrapTransparent(tree, function_index))) {
        .function => |function| function,
        .arrow_function_expression => |arrow| return if (arrow.expression) arrow.body else returnArgumentFromBody(tree, arrow.body),
        else => return null,
    };
    return returnArgumentFromBody(tree, function.body);
}

fn returnArgumentFromBody(tree: *const ast.Tree, body_index: ast.NodeIndex) ?ast.NodeIndex {
    if (body_index == .null) return null;
    const body = switch (tree.data(body_index)) {
        .function_body => |body| body.body,
        .block_statement => |block| block.body,
        else => return null,
    };
    return returnArgumentFromRange(tree, body);
}

fn returnArgumentFromRange(tree: *const ast.Tree, range: ast.IndexRange) ?ast.NodeIndex {
    for (tree.extra(range)) |statement_index| {
        const statement = unwrapTransparent(tree, statement_index);
        switch (tree.data(statement)) {
            .return_statement => |return_statement| return return_statement.argument,
            .block_statement => |block| if (returnArgumentFromRange(tree, block.body)) |argument| return argument,
            .if_statement => |if_statement| {
                if (returnArgumentFromStatement(tree, if_statement.consequent)) |argument| return argument;
                if (returnArgumentFromStatement(tree, if_statement.alternate)) |argument| return argument;
            },
            .function, .arrow_function_expression => {},
            else => {},
        }
    }
    return null;
}

fn returnArgumentFromStatement(tree: *const ast.Tree, statement: ast.NodeIndex) ?ast.NodeIndex {
    if (statement == .null) return null;
    switch (tree.data(unwrapTransparent(tree, statement))) {
        .return_statement => |return_statement| return return_statement.argument,
        .block_statement => |block| return returnArgumentFromRange(tree, block.body),
        else => return null,
    }
}

fn isPropTypesKey(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) bool {
    const name = propertyName(tree, key, computed) orelse return false;
    return std.mem.eql(u8, name, "propTypes");
}

fn callExpression(tree: *const ast.Tree, node: ast.NodeIndex) ?ast.CallExpression {
    return switch (tree.data(unwrapTransparent(tree, node))) {
        .call_expression => |call| call,
        else => null,
    };
}

fn importSpecifierLocalName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .import_specifier => |specifier| bindingIdentifierName(tree, specifier.local),
        .import_default_specifier => |specifier| bindingIdentifierName(tree, specifier.local),
        .import_namespace_specifier => |specifier| bindingIdentifierName(tree, specifier.local),
        else => null,
    };
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (computed or index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
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
