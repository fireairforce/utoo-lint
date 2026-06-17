const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/default-props-match-prop-types";

pub const Options = struct {
    allow_required_defaults: bool = false,
};

const PropInfo = struct {
    name: []const u8,
    required: bool,
};

const DefaultInfo = struct {
    name: []const u8,
    node: ast.NodeIndex,
};

const ComponentInfo = struct {
    name: ?[]const u8 = null,
    node: ast.NodeIndex = .null,
    detected: bool = false,
    prop_types: std.ArrayList(PropInfo) = .empty,
    default_props: std.ArrayList(DefaultInfo) = .empty,
    prop_types_unresolved: bool = false,
    default_props_unresolved: bool = false,

    fn deinit(self: *ComponentInfo, allocator: Allocator) void {
        self.prop_types.deinit(allocator);
        self.default_props.deinit(allocator);
    }
};

pub const State = struct {
    components: std.ArrayList(ComponentInfo) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        for (self.components.items) |*component| {
            component.deinit(allocator);
        }
        self.components.deinit(allocator);
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
        switch (tree.data(statement_index)) {
            .class => |class| try collectClass(allocator, tree, class, statement_index, state),
            .function => |function| try collectFunction(allocator, tree, function, statement_index, state),
            .variable_declaration => |declaration| {
                for (tree.extra(declaration.declarators)) |declarator_index| {
                    const declarator = switch (tree.data(declarator_index)) {
                        .variable_declarator => |declarator| declarator,
                        else => continue,
                    };
                    try collectVariableDeclarator(allocator, tree, declarator, declarator_index, state);
                }
            },
            .expression_statement => |statement| {
                const assignment = switch (tree.data(unwrapTransparent(tree, statement.expression))) {
                    .assignment_expression => |assignment| assignment,
                    else => continue,
                };
                try collectAssignmentExpression(allocator, tree, assignment, state);
            },
            .export_named_declaration => |declaration| try collectExportDeclaration(allocator, tree, declaration.declaration, state),
            .export_default_declaration => |declaration| try collectExportDeclaration(allocator, tree, declaration.declaration, state),
            else => {},
        }
    }
}

fn collectExportDeclaration(
    allocator: Allocator,
    tree: *const ast.Tree,
    declaration_index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    if (declaration_index == .null) return;
    switch (tree.data(declaration_index)) {
        .class => |class| try collectClass(allocator, tree, class, declaration_index, state),
        .function => |function| try collectFunction(allocator, tree, function, declaration_index, state),
        .variable_declaration => |declaration| {
            for (tree.extra(declaration.declarators)) |declarator_index| {
                const declarator = switch (tree.data(declarator_index)) {
                    .variable_declarator => |declarator| declarator,
                    else => continue,
                };
                try collectVariableDeclarator(allocator, tree, declarator, declarator_index, state);
            }
        },
        else => {},
    }
}

fn collectFunction(
    allocator: Allocator,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    const name = bindingIdentifierName(tree, function.id) orelse return;
    if (!isComponentName(name)) return;
    _ = try ensureComponent(allocator, state, name, index, true);
}

pub fn collectClass(
    allocator: Allocator,
    tree: *const ast.Tree,
    class: ast.Class,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    const name = bindingIdentifierName(tree, class.id) orelse return;
    const component_index = try ensureComponent(allocator, state, name, index, true);
    const body = switch (tree.data(class.body)) {
        .class_body => |body| body,
        else => return,
    };

    for (tree.extra(body.body)) |member_index| {
        switch (tree.data(member_index)) {
            .property_definition => |property| {
                if (!property.static) continue;
                const key = propertyName(tree, property.key, property.computed) orelse continue;
                if (std.mem.eql(u8, key, "propTypes")) {
                    try collectPropTypesValue(allocator, tree, property.value, component_index, state);
                } else if (std.mem.eql(u8, key, "defaultProps")) {
                    try collectDefaultPropsValue(allocator, tree, property.value, component_index, state);
                }
            },
            .method_definition => |method| {
                if (!method.static) continue;
                const key = propertyName(tree, method.key, method.computed) orelse continue;
                if (!std.mem.eql(u8, key, "getDefaultProps")) continue;
                const returned = returnArgument(tree, method.value) orelse {
                    state.components.items[component_index].default_props_unresolved = true;
                    continue;
                };
                try collectDefaultPropsValue(allocator, tree, returned, component_index, state);
            },
            else => {},
        }
    }
}

pub fn collectVariableDeclarator(
    allocator: Allocator,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    const name = bindingIdentifierName(tree, declarator.id) orelse return;
    if (declarator.init == .null) return;
    if (isComponentName(name)) {
        switch (tree.data(unwrapTransparent(tree, declarator.init))) {
            .function, .arrow_function_expression => {
                _ = try ensureComponent(allocator, state, name, index, true);
            },
            else => {},
        }
    }

    const call = switch (tree.data(unwrapTransparent(tree, declarator.init))) {
        .call_expression => |call| call,
        else => return,
    };
    if (!isCreateReactClassCall(tree, call)) return;

    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return;
    const object = switch (tree.data(unwrapTransparent(tree, arguments[0]))) {
        .object_expression => |object| object,
        else => return,
    };

    const component_index = try ensureComponent(allocator, state, name, index, true);
    try collectCreateClassObject(allocator, tree, object, component_index, state);
}

pub fn collectAssignmentExpression(
    allocator: Allocator,
    tree: *const ast.Tree,
    assignment: ast.AssignmentExpression,
    state: *State,
) Allocator.Error!void {
    if (assignment.operator != .assign) return;
    const target = assignmentTarget(tree, assignment.left) orelse return;
    const component_index = try ensureComponent(allocator, state, target.component, assignment.left, false);

    switch (target.kind) {
        .prop_types => {
            if (target.prop) |prop| {
                try addPropType(allocator, &state.components.items[component_index], prop, isRequiredPropType(tree, assignment.right));
            } else {
                try collectPropTypesValue(allocator, tree, assignment.right, component_index, state);
            }
        },
        .default_props => {
            if (target.prop) |prop| {
                try addDefaultProp(allocator, &state.components.items[component_index], prop, assignment.left);
            } else {
                try collectDefaultPropsValue(allocator, tree, assignment.right, component_index, state);
            }
        },
    }
}

pub fn finish(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    state: *State,
    options: Options,
) Allocator.Error!void {
    for (state.components.items) |component| {
        if (!component.detected) continue;
        if (component.default_props_unresolved or component.prop_types_unresolved) continue;
        if (component.default_props.items.len == 0 or component.prop_types.items.len == 0) continue;

        for (component.default_props.items) |default_prop| {
            const prop = findProp(component, default_prop.name);
            if (prop == null) {
                try core.addDiagnosticFmt(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    tree.span(default_prop.node),
                    "defaultProp \"{s}\" has no corresponding propTypes declaration.",
                    .{default_prop.name},
                );
            } else if (prop.?.required and !options.allow_required_defaults) {
                try core.addDiagnosticFmt(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    tree.span(default_prop.node),
                    "defaultProp \"{s}\" defined for isRequired propType.",
                    .{default_prop.name},
                );
            }
        }
    }
}

fn collectCreateClassObject(
    allocator: Allocator,
    tree: *const ast.Tree,
    object: ast.ObjectExpression,
    component_index: usize,
    state: *State,
) Allocator.Error!void {
    for (tree.extra(object.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        const key = propertyName(tree, property.key, property.computed) orelse continue;
        if (std.mem.eql(u8, key, "propTypes")) {
            try collectPropTypesValue(allocator, tree, property.value, component_index, state);
        } else if (std.mem.eql(u8, key, "defaultProps")) {
            try collectDefaultPropsValue(allocator, tree, property.value, component_index, state);
        } else if (std.mem.eql(u8, key, "getDefaultProps")) {
            const returned = returnArgument(tree, property.value) orelse {
                state.components.items[component_index].default_props_unresolved = true;
                continue;
            };
            try collectDefaultPropsValue(allocator, tree, returned, component_index, state);
        }
    }
}

fn collectPropTypesValue(
    allocator: Allocator,
    tree: *const ast.Tree,
    value: ast.NodeIndex,
    component_index: usize,
    state: *State,
) Allocator.Error!void {
    if (value == .null) {
        state.components.items[component_index].prop_types_unresolved = true;
        return;
    }
    const object = switch (tree.data(unwrapTransparent(tree, value))) {
        .object_expression => |object| object,
        else => {
            state.components.items[component_index].prop_types_unresolved = true;
            return;
        },
    };

    for (tree.extra(object.properties)) |property_index| {
        switch (tree.data(property_index)) {
            .object_property => |property| {
                const name = propertyName(tree, property.key, property.computed) orelse continue;
                try addPropType(allocator, &state.components.items[component_index], name, isRequiredPropType(tree, property.value));
            },
            .spread_element => state.components.items[component_index].prop_types_unresolved = true,
            else => {},
        }
    }
}

fn collectDefaultPropsValue(
    allocator: Allocator,
    tree: *const ast.Tree,
    value: ast.NodeIndex,
    component_index: usize,
    state: *State,
) Allocator.Error!void {
    if (value == .null) {
        state.components.items[component_index].default_props_unresolved = true;
        return;
    }
    const object = switch (tree.data(unwrapTransparent(tree, value))) {
        .object_expression => |object| object,
        else => {
            state.components.items[component_index].default_props_unresolved = true;
            return;
        },
    };

    for (tree.extra(object.properties)) |property_index| {
        switch (tree.data(property_index)) {
            .object_property => |property| {
                const name = propertyName(tree, property.key, property.computed) orelse continue;
                try addDefaultProp(allocator, &state.components.items[component_index], name, property_index);
            },
            .spread_element => state.components.items[component_index].default_props_unresolved = true,
            else => {},
        }
    }
}

fn ensureComponent(
    allocator: Allocator,
    state: *State,
    name: []const u8,
    node: ast.NodeIndex,
    detected: bool,
) Allocator.Error!usize {
    for (state.components.items, 0..) |*component, index| {
        if (component.name) |existing| {
            if (std.mem.eql(u8, existing, name)) {
                component.detected = component.detected or detected;
                return index;
            }
        }
    }

    try state.components.append(allocator, .{ .name = name, .node = node, .detected = detected });
    return state.components.items.len - 1;
}

fn addPropType(
    allocator: Allocator,
    component: *ComponentInfo,
    name: []const u8,
    required: bool,
) Allocator.Error!void {
    for (component.prop_types.items) |*prop| {
        if (std.mem.eql(u8, prop.name, name)) {
            prop.required = required;
            return;
        }
    }
    try component.prop_types.append(allocator, .{ .name = name, .required = required });
}

fn addDefaultProp(
    allocator: Allocator,
    component: *ComponentInfo,
    name: []const u8,
    node: ast.NodeIndex,
) Allocator.Error!void {
    for (component.default_props.items) |default_prop| {
        if (std.mem.eql(u8, default_prop.name, name)) return;
    }
    try component.default_props.append(allocator, .{ .name = name, .node = node });
}

fn findProp(component: ComponentInfo, name: []const u8) ?PropInfo {
    for (component.prop_types.items) |prop| {
        if (std.mem.eql(u8, prop.name, name)) return prop;
    }
    return null;
}

const AssignmentKind = enum { prop_types, default_props };

const AssignmentTarget = struct {
    component: []const u8,
    kind: AssignmentKind,
    prop: ?[]const u8 = null,
};

fn assignmentTarget(tree: *const ast.Tree, index: ast.NodeIndex) ?AssignmentTarget {
    const member = switch (tree.data(unwrapTransparent(tree, index))) {
        .member_expression => |member| member,
        else => return null,
    };
    const property = propertyName(tree, member.property, member.computed) orelse return null;

    if (assignmentKind(property)) |kind| {
        const component = componentName(tree, member.object) orelse return null;
        return .{ .component = component, .kind = kind };
    }

    const parent = switch (tree.data(unwrapTransparent(tree, member.object))) {
        .member_expression => |parent| parent,
        else => return null,
    };
    const parent_property = propertyName(tree, parent.property, parent.computed) orelse return null;
    const kind = assignmentKind(parent_property) orelse return null;
    const component = componentName(tree, parent.object) orelse return null;
    return .{ .component = component, .kind = kind, .prop = property };
}

fn assignmentKind(name: []const u8) ?AssignmentKind {
    if (std.mem.eql(u8, name, "propTypes")) return .prop_types;
    if (std.mem.eql(u8, name, "defaultProps")) return .default_props;
    return null;
}

fn componentName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isRequiredPropType(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    const member = switch (tree.data(unwrapTransparent(tree, index))) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member.property, member.computed) orelse return false;
    if (std.mem.eql(u8, property, "isRequired")) return true;
    return false;
}

fn isCreateReactClassCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createReactClass");
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member.property, member.computed) orelse return false;
    if (!std.mem.eql(u8, property, "createClass")) return false;
    const object = identifierReferenceName(tree, unwrapTransparent(tree, member.object)) orelse return false;
    return std.mem.eql(u8, object, "React");
}

fn returnArgument(tree: *const ast.Tree, function_index: ast.NodeIndex) ?ast.NodeIndex {
    if (function_index == .null) return null;
    const function = switch (tree.data(unwrapTransparent(tree, function_index))) {
        .function => |function| function,
        else => return null,
    };
    const body = switch (tree.data(function.body)) {
        .function_body => |body| body,
        else => return null,
    };

    for (tree.extra(body.body)) |statement_index| {
        const statement = switch (tree.data(statement_index)) {
            .return_statement => |statement| statement,
            else => continue,
        };
        return statement.argument;
    }
    return null;
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

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (index == .null) return null;
    return if (computed)
        switch (tree.data(index)) {
            .string_literal => |literal| tree.string(literal.value),
            else => null,
        }
    else switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isComponentName(name: []const u8) bool {
    if (name.len == 0) return false;
    return std.ascii.isUpper(name[0]);
}
