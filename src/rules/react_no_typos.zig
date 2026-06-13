const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/no-typos";

const static_class_properties = [_][]const u8{
    "propTypes",
    "contextTypes",
    "childContextTypes",
    "defaultProps",
};

const prop_types = [_][]const u8{
    "array",
    "bigint",
    "bool",
    "func",
    "number",
    "object",
    "string",
    "symbol",
    "any",
    "arrayOf",
    "element",
    "elementType",
    "instanceOf",
    "node",
    "objectOf",
    "oneOf",
    "oneOfType",
    "shape",
    "exact",
    "checkPropTypes",
    "resetWarningCache",
    "PropTypes",
};

const static_lifecycle_methods = [_][]const u8{
    "getDerivedStateFromProps",
};

const instance_lifecycle_methods = [_][]const u8{
    "getDefaultProps",
    "getInitialState",
    "getChildContext",
    "componentWillMount",
    "UNSAFE_componentWillMount",
    "componentDidMount",
    "componentWillReceiveProps",
    "UNSAFE_componentWillReceiveProps",
    "shouldComponentUpdate",
    "componentWillUpdate",
    "UNSAFE_componentWillUpdate",
    "getSnapshotBeforeUpdate",
    "componentDidUpdate",
    "componentDidCatch",
    "componentWillUnmount",
    "render",
};

pub const State = struct {
    prop_types_package_name: ?[]const u8 = null,
    react_package_name: ?[]const u8 = null,
    component_names: std.ArrayList([]const u8) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.component_names.deinit(allocator);
        self.* = .{};
    }
};

pub fn collectProgram(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
    state: *State,
) Allocator.Error!void {
    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .import_declaration => |declaration| try scanImportDeclaration(allocator, diagnostics, tree, declaration, state),
            .class => |class| try rememberClassComponent(allocator, tree, class, state),
            .variable_declaration => |declaration| try scanVariableDeclaration(allocator, tree, declaration, state),
            else => {},
        }
    }
}

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
    state: State,
) Allocator.Error!void {
    if (!isReactComponentClass(tree, class)) return;
    const body = switch (tree.data(class.body)) {
        .class_body => |body| body,
        else => return,
    };

    for (tree.extra(body.body)) |member_index| {
        switch (tree.data(member_index)) {
            .method_definition => |method| try checkLifecycleMethod(allocator, diagnostics, tree, method.key, method.computed, method.static, member_index),
            .property_definition => |property| {
                if (!property.static) continue;
                try checkStaticPropertyCasing(allocator, diagnostics, tree, property.value, property.key, property.computed, true, state);
            },
            else => {},
        }
    }
}

pub fn checkObjectExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    object: ast.ObjectExpression,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
    state: State,
) Allocator.Error!void {
    if (!isCreateClassObject(tree, index, parent_index) and !isRememberedCreateClassObject(tree, index, state)) return;

    for (tree.extra(object.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        try checkStaticPropertyCasing(allocator, diagnostics, tree, property.value, property.key, property.computed, false, state);
        try checkLifecycleMethod(allocator, diagnostics, tree, property.key, property.computed, false, property_index);
    }
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    ctx: *traverser.basic.Ctx,
    state: State,
) Allocator.Error!void {
    if (!property.static) return;
    const class_index = classAncestor(ctx) orelse return;
    const class = switch (tree.data(class_index)) {
        .class => |class| class,
        else => return,
    };
    if (!isReactComponentClass(tree, class)) return;
    try checkStaticPropertyCasing(allocator, diagnostics, tree, property.value, property.key, property.computed, true, state);
}

pub fn checkMethodDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    method: ast.MethodDefinition,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    const class_index = classAncestor(ctx) orelse return;
    const class = switch (tree.data(class_index)) {
        .class => |class| class,
        else => return,
    };
    if (!isReactComponentClass(tree, class)) return;
    try checkLifecycleMethod(allocator, diagnostics, tree, method.key, method.computed, method.static, index);
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
    if (member.computed) return;
    const object_name = identifierReferenceName(tree, member.object) orelse return;
    if (!isKnownComponentName(object_name, state) and !startsUppercase(object_name)) return;
    try checkStaticPropertyCasing(allocator, diagnostics, tree, expression.right, member.property, false, true, state);
}

fn scanImportDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    state: *State,
) Allocator.Error!void {
    if (declaration.import_kind == .type) return;
    const source = stringLiteralValue(tree, declaration.source) orelse return;
    const specifiers = tree.extra(declaration.specifiers);

    if (std.mem.eql(u8, source, "prop-types")) {
        if (specifiers.len == 0) {
            try core.addDiagnostic(allocator, diagnostics, .@"error", id, "`'prop-types'` imported without a local `PropTypes` binding.", tree.span(declaration.source));
            return;
        }
        state.prop_types_package_name = importSpecifierLocalName(tree, specifiers[0]);
        return;
    }

    if (!std.mem.eql(u8, source, "react")) return;
    if (specifiers.len == 0) {
        try core.addDiagnostic(allocator, diagnostics, .@"error", id, "`'react'` imported without a local `React` binding.", tree.span(declaration.source));
        return;
    }
    state.react_package_name = importSpecifierLocalName(tree, specifiers[0]);

    for (specifiers) |specifier_index| {
        const specifier = switch (tree.data(specifier_index)) {
            .import_specifier => |specifier| specifier,
            else => continue,
        };
        const imported = propertyName(tree, specifier.imported, false) orelse continue;
        if (!std.mem.eql(u8, imported, "PropTypes")) continue;
        state.prop_types_package_name = bindingIdentifierName(tree, specifier.local);
    }
}

fn scanVariableDeclaration(
    allocator: Allocator,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    state: *State,
) Allocator.Error!void {
    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |declarator| declarator,
            else => continue,
        };
        const name = bindingIdentifierName(tree, declarator.id) orelse continue;
        if (declarator.init == .null) continue;
        if (isCreateClassCall(tree, declarator.init) or isReactComponentClassExpression(tree, declarator.init)) {
            try rememberComponentName(allocator, state, name);
        }
    }
}

fn rememberClassComponent(allocator: Allocator, tree: *const ast.Tree, class: ast.Class, state: *State) Allocator.Error!void {
    if (!isReactComponentClass(tree, class)) return;
    const name = bindingIdentifierName(tree, class.id) orelse return;
    try rememberComponentName(allocator, state, name);
}

fn rememberComponentName(allocator: Allocator, state: *State, name: []const u8) Allocator.Error!void {
    for (state.component_names.items) |component_name| {
        if (std.mem.eql(u8, component_name, name)) return;
    }
    try state.component_names.append(allocator, name);
}

fn checkStaticPropertyCasing(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    value: ast.NodeIndex,
    key: ast.NodeIndex,
    computed: bool,
    is_class_property: bool,
    state: State,
) Allocator.Error!void {
    const name = propertyName(tree, key, computed) orelse return;
    if (std.mem.eql(u8, name, "propTypes") or
        std.mem.eql(u8, name, "contextTypes") or
        std.mem.eql(u8, name, "childContextTypes"))
    {
        try checkPropObject(allocator, diagnostics, tree, value, state);
    }

    for (static_class_properties) |static_property| {
        if (asciiEqlIgnoreCase(name, static_property) and !std.mem.eql(u8, name, static_property)) {
            const message = if (is_class_property)
                "Typo in static class property declaration"
            else
                "Typo in property declaration";
            try core.addDiagnostic(allocator, diagnostics, .@"error", id, message, tree.span(key));
        }
    }
}

fn checkLifecycleMethod(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    key: ast.NodeIndex,
    computed: bool,
    is_static: bool,
    diagnostic_node: ast.NodeIndex,
) Allocator.Error!void {
    const name = propertyName(tree, key, computed) orelse return;
    for (static_lifecycle_methods) |method| {
        if (!is_static and asciiEqlIgnoreCase(name, method)) {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .@"error",
                id,
                tree.span(diagnostic_node),
                "Lifecycle method should be static: {s}",
                .{name},
            );
        }
    }

    for (instance_lifecycle_methods) |method| {
        try reportLifecycleTypo(allocator, diagnostics, tree, diagnostic_node, name, method);
    }
    for (static_lifecycle_methods) |method| {
        try reportLifecycleTypo(allocator, diagnostics, tree, diagnostic_node, name, method);
    }
}

fn reportLifecycleTypo(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    diagnostic_node: ast.NodeIndex,
    actual: []const u8,
    expected: []const u8,
) Allocator.Error!void {
    if (!asciiEqlIgnoreCase(actual, expected) or std.mem.eql(u8, actual, expected)) return;
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(diagnostic_node),
        "Typo in component lifecycle method declaration: {s} should be {s}",
        .{ actual, expected },
    );
}

fn checkPropObject(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    state: State,
) Allocator.Error!void {
    const object = switch (tree.data(unwrapTransparent(tree, node))) {
        .object_expression => |object| object,
        else => return,
    };
    for (tree.extra(object.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        try checkProp(allocator, diagnostics, tree, property.value, state);
    }
}

fn checkProp(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    state: State,
) Allocator.Error!void {
    if (node == .null) return;
    const current = unwrapTransparent(tree, node);
    switch (tree.data(current)) {
        .member_expression => |member| {
            if (member.computed) return;
            if (isPropTypesPackage(tree, member.object, state)) {
                const name = propertyName(tree, member.property, false) orelse return;
                if (!std.mem.eql(u8, name, "isRequired")) {
                    try checkValidPropType(allocator, diagnostics, tree, member.property, name);
                }
                return;
            }

            const object_member = switch (tree.data(unwrapTransparent(tree, member.object))) {
                .member_expression => |object_member| object_member,
                else => null,
            };
            if (object_member) |object| {
                if (!object.computed and isPropTypesPackage(tree, object.object, state)) {
                    const prop_type_name = propertyName(tree, object.property, false) orelse return;
                    try checkValidPropType(allocator, diagnostics, tree, object.property, prop_type_name);
                    const qualifier = propertyName(tree, member.property, false) orelse return;
                    try checkValidPropTypeQualifier(allocator, diagnostics, tree, member.property, qualifier);
                    return;
                }
            }

            if (isCallExpression(tree, member.object)) {
                const qualifier = propertyName(tree, member.property, false) orelse return;
                try checkValidPropTypeQualifier(allocator, diagnostics, tree, member.property, qualifier);
                try checkValidCallExpression(allocator, diagnostics, tree, member.object, state);
            }
        },
        .call_expression => try checkValidCallExpression(allocator, diagnostics, tree, current, state),
        else => {},
    }
}

fn checkValidCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    state: State,
) Allocator.Error!void {
    const call = switch (tree.data(unwrapTransparent(tree, node))) {
        .call_expression => |call| call,
        else => return,
    };
    const callee = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return,
    };
    if (callee.computed) return;
    const callee_name = propertyName(tree, callee.property, false) orelse return;
    const arguments = tree.extra(call.arguments);

    if (std.mem.eql(u8, callee_name, "shape") or std.mem.eql(u8, callee_name, "exact")) {
        if (arguments.len > 0) try checkPropObject(allocator, diagnostics, tree, arguments[0], state);
    } else if (std.mem.eql(u8, callee_name, "oneOfType")) {
        if (arguments.len == 0) return;
        const array = switch (tree.data(unwrapTransparent(tree, arguments[0]))) {
            .array_expression => |array| array,
            else => return,
        };
        for (tree.extra(array.elements)) |element| {
            try checkProp(allocator, diagnostics, tree, element, state);
        }
    }
}

fn checkValidPropType(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    name: []const u8,
) Allocator.Error!void {
    for (prop_types) |prop_type| {
        if (std.mem.eql(u8, name, prop_type)) return;
    }
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(node),
        "Typo in declared prop type: {s}",
        .{name},
    );
}

fn checkValidPropTypeQualifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    name: []const u8,
) Allocator.Error!void {
    if (std.mem.eql(u8, name, "isRequired")) return;
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(node),
        "Typo in prop type chain qualifier: {s}",
        .{name},
    );
}

fn isPropTypesPackage(tree: *const ast.Tree, node: ast.NodeIndex, state: State) bool {
    if (state.prop_types_package_name) |name| {
        if (identifierReferenceEquals(tree, node, name)) return true;
    }

    const react_name = state.react_package_name orelse "React";
    const member = switch (tree.data(unwrapTransparent(tree, node))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    if (!identifierReferenceEquals(tree, member.object, react_name)) return false;
    const property = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, property, "PropTypes");
}

fn isKnownComponentName(name: []const u8, state: State) bool {
    for (state.component_names.items) |component_name| {
        if (std.mem.eql(u8, name, component_name)) return true;
    }
    return false;
}

fn isRememberedCreateClassObject(tree: *const ast.Tree, index: ast.NodeIndex, state: State) bool {
    _ = tree;
    _ = index;
    _ = state;
    return false;
}

fn classAncestor(ctx: *traverser.basic.Ctx) ?ast.NodeIndex {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (ctx.tree.data(ancestor)) {
            .class => return ancestor,
            else => {},
        }
    }
    return null;
}

fn isReactComponentClassExpression(tree: *const ast.Tree, node: ast.NodeIndex) bool {
    const class = switch (tree.data(unwrapTransparent(tree, node))) {
        .class => |class| class,
        else => return false,
    };
    return isReactComponentClass(tree, class);
}

fn isReactComponentClass(tree: *const ast.Tree, class: ast.Class) bool {
    if (class.super_class == .null) return false;
    const super_class = unwrapTransparent(tree, class.super_class);
    if (identifierReferenceName(tree, super_class)) |name| {
        return std.mem.eql(u8, name, "Component") or std.mem.eql(u8, name, "PureComponent");
    }

    const member = switch (tree.data(super_class)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    if (!identifierReferenceEquals(tree, unwrapTransparent(tree, member.object), "React")) return false;
    const property = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, property, "Component") or std.mem.eql(u8, property, "PureComponent");
}

fn isCreateClassObject(tree: *const ast.Tree, index: ast.NodeIndex, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    const call = switch (tree.data(parent)) {
        .call_expression => |call| call,
        else => return false,
    };
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0 or arguments[0] != index) return false;
    return isCreateClassCallExpression(tree, call);
}

fn isCreateClassCall(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const call = switch (tree.data(unwrapTransparent(tree, index))) {
        .call_expression => |call| call,
        else => return false,
    };
    return isCreateClassCallExpression(tree, call);
}

fn isCreateClassCallExpression(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createReactClass");
    }
    return false;
}

fn importSpecifierLocalName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .import_specifier => |specifier| bindingIdentifierName(tree, specifier.local),
        .import_default_specifier => |specifier| bindingIdentifierName(tree, specifier.local),
        .import_namespace_specifier => |specifier| bindingIdentifierName(tree, specifier.local),
        else => null,
    };
}

fn isCallExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .call_expression => true,
        else => false,
    };
}

fn startsUppercase(name: []const u8) bool {
    return name.len > 0 and std.ascii.isUpper(name[0]);
}

fn asciiEqlIgnoreCase(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(a, b);
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

fn identifierReferenceEquals(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    const name = identifierReferenceName(tree, index) orelse return false;
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
