const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/no-unused-state";

const StateField = struct {
    name: []const u8,
    node: ast.NodeIndex,
};

pub const State = struct {
    active: bool = false,
    abandoned: bool = false,
    component_index: ast.NodeIndex = .null,
    aliases_active: bool = false,
    state_param_name: ?[]const u8 = null,
    state_fields: std.ArrayList(StateField) = .empty,
    used_state_fields: std.StringHashMapUnmanaged(void) = .empty,
    aliases: std.StringHashMapUnmanaged(void) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.state_fields.deinit(allocator);
        self.used_state_fields.deinit(allocator);
        self.aliases.deinit(allocator);
        self.* = .{};
    }

    fn beginComponent(self: *State, allocator: Allocator, index: ast.NodeIndex) Allocator.Error!void {
        if (self.active) return;
        self.state_fields.clearRetainingCapacity();
        self.used_state_fields.clearRetainingCapacity();
        self.aliases.clearRetainingCapacity();
        self.active = true;
        self.abandoned = false;
        self.component_index = index;
        self.aliases_active = false;
        self.state_param_name = null;
        try self.used_state_fields.ensureTotalCapacity(allocator, 16);
        try self.aliases.ensureTotalCapacity(allocator, 8);
    }

    fn finishComponent(
        self: *State,
        allocator: Allocator,
        diagnostics: *core.DiagnosticList,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
    ) Allocator.Error!void {
        if (!self.active or self.component_index != index) return;
        defer {
            self.active = false;
            self.abandoned = false;
            self.component_index = .null;
            self.aliases_active = false;
            self.state_param_name = null;
            self.state_fields.clearRetainingCapacity();
            self.used_state_fields.clearRetainingCapacity();
            self.aliases.clearRetainingCapacity();
        }

        if (self.abandoned) return;

        for (self.state_fields.items) |field| {
            if (self.used_state_fields.contains(field.name)) continue;
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .@"error",
                id,
                tree.span(field.node),
                "Unused state field: '{s}'",
                .{field.name},
            );
        }
    }

    fn addStateField(self: *State, allocator: Allocator, name: []const u8, node: ast.NodeIndex) Allocator.Error!void {
        if (!self.active or self.abandoned) return;
        for (self.state_fields.items) |field| {
            if (std.mem.eql(u8, field.name, name)) return;
        }
        try self.state_fields.append(allocator, .{ .name = name, .node = node });
    }

    fn addUsedStateField(self: *State, allocator: Allocator, name: []const u8) Allocator.Error!void {
        if (!self.active or self.abandoned) return;
        try self.used_state_fields.put(allocator, name, {});
    }

    fn addAlias(self: *State, allocator: Allocator, name: []const u8) Allocator.Error!void {
        if (!self.active or self.abandoned or !self.aliases_active) return;
        try self.aliases.put(allocator, name, {});
    }
};

pub fn enterClass(
    allocator: Allocator,
    tree: *const ast.Tree,
    class: ast.Class,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    if (isReactComponentClass(tree, class)) {
        try state.beginComponent(allocator, index);
    }
}

pub fn exitClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    try state.finishComponent(allocator, diagnostics, tree, index);
}

pub fn enterObjectExpression(
    allocator: Allocator,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    if (isCreateClassObject(tree, index, parent_index)) {
        try state.beginComponent(allocator, index);
    }
}

pub fn exitObjectExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    try state.finishComponent(allocator, diagnostics, tree, index);
}

pub fn enterMethodDefinition(
    allocator: Allocator,
    tree: *const ast.Tree,
    method: ast.MethodDefinition,
    state: *State,
) Allocator.Error!void {
    if (!state.active or state.abandoned) return;
    state.aliases_active = true;
    state.aliases.clearRetainingCapacity();
    state.state_param_name = lifecycleStateParameterName(tree, method);
    try state.aliases.ensureTotalCapacity(allocator, 8);
}

pub fn exitMethodDefinition(_: ast.MethodDefinition, state: *State) void {
    if (!state.active) return;
    state.aliases_active = false;
    state.aliases.clearRetainingCapacity();
    state.state_param_name = null;
}

pub fn enterPropertyDefinition(
    allocator: Allocator,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    state: *State,
) Allocator.Error!void {
    if (!state.active or state.abandoned) return;

    const name = propertyName(tree, property.key, property.computed);
    if (!property.static and name != null and std.mem.eql(u8, name.?, "state")) {
        if (objectExpression(tree, property.value)) |object| {
            try addStateFieldsFromObject(allocator, tree, object, state);
        }
    }

    if (!property.static and isArrowFunctionExpression(tree, property.value)) {
        state.aliases_active = true;
        state.aliases.clearRetainingCapacity();
        state.state_param_name = null;
        try state.aliases.ensureTotalCapacity(allocator, 8);
    }
}

pub fn exitPropertyDefinition(property: ast.PropertyDefinition, tree: *const ast.Tree, state: *State) void {
    if (!state.active) return;
    if (!property.static and isArrowFunctionExpression(tree, property.value)) {
        state.aliases_active = false;
        state.aliases.clearRetainingCapacity();
        state.state_param_name = null;
    }
}

pub fn enterObjectProperty(
    allocator: Allocator,
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    if (!state.active or state.abandoned) return;
    const parent = parent_index orelse return;
    if (state.component_index != parent) return;

    const key = propertyName(tree, property.key, property.computed) orelse return;
    if (std.mem.eql(u8, key, "getInitialState")) {
        const returned = returnArgument(tree, property.value) orelse return;
        if (objectExpression(tree, returned)) |object| {
            try addStateFieldsFromObject(allocator, tree, object, state);
        }
        return;
    }

    if (isFunctionLike(tree, property.value)) {
        _ = index;
        state.aliases_active = true;
        state.aliases.clearRetainingCapacity();
        state.state_param_name = null;
        try state.aliases.ensureTotalCapacity(allocator, 8);
    }
}

pub fn exitObjectProperty(property: ast.ObjectProperty, tree: *const ast.Tree, parent_index: ?ast.NodeIndex, state: *State) void {
    if (!state.active) return;
    const parent = parent_index orelse return;
    if (state.component_index != parent) return;
    const key = propertyName(tree, property.key, property.computed) orelse return;
    if (!std.mem.eql(u8, key, "getInitialState") and isFunctionLike(tree, property.value)) {
        state.aliases_active = false;
        state.aliases.clearRetainingCapacity();
        state.state_param_name = null;
    }
}

pub fn checkCallExpression(
    allocator: Allocator,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    state: *State,
) Allocator.Error!void {
    if (!state.active or state.abandoned) return;
    if (!isSetStateCall(tree, call)) return;

    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return;

    const first = unwrapTransparent(tree, arguments[0]);
    if (objectExpression(tree, first)) |object| {
        try addStateFieldsFromObject(allocator, tree, object, state);
        return;
    }

    const arrow = switch (tree.data(first)) {
        .arrow_function_expression => |arrow| arrow,
        else => return,
    };
    if (objectExpression(tree, arrow.body)) |object| {
        try addStateFieldsFromObject(allocator, tree, object, state);
    }
    if (firstParameter(allocator, tree, arrow.params)) |param| {
        switch (param.kind) {
            .name => try state.addAlias(allocator, param.name.?),
            .object_pattern => try handleStateDestructuring(allocator, tree, param.node, state),
            .none => {},
        }
    }
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    ctx: *traverser.basic.Ctx,
    state: *State,
) Allocator.Error!void {
    if (!state.active or state.abandoned) return;

    const left = unwrapTransparent(tree, expression.left);
    const right = unwrapTransparent(tree, expression.right);

    if (isThisStateMember(tree, left) and objectExpression(tree, right) != null and inConstructor(tree, ctx)) {
        try addStateFieldsFromObject(allocator, tree, objectExpression(tree, right).?, state);
        return;
    }

    try handleAssignment(allocator, tree, left, right, state);
}

pub fn checkVariableDeclarator(
    allocator: Allocator,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    state: *State,
) Allocator.Error!void {
    if (!state.active or state.abandoned or declarator.init == .null) return;
    try handleAssignment(allocator, tree, declarator.id, declarator.init, state);
}

pub fn checkMemberExpression(
    allocator: Allocator,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    state: *State,
) Allocator.Error!void {
    if (!state.active or state.abandoned) return;

    if (isStateReference(tree, member.object, state)) {
        if (member.computed and propertyName(tree, member.property, true) == null) {
            state.abandoned = true;
            return;
        }
        if (propertyName(tree, member.property, member.computed)) |name| {
            try state.addUsedStateField(allocator, name);
        }
        return;
    }

    if (isStateReference(tree, index, state)) {
        const parent = ctx.path.ancestor(1) orelse return;
        if (tree.data(parent) == .call_expression) {
            state.abandoned = true;
        }
    }
}

pub fn checkJSXSpreadAttribute(tree: *const ast.Tree, attribute: ast.JSXSpreadAttribute, state: *State) void {
    if (state.active and isStateReference(tree, attribute.argument, state)) {
        state.abandoned = true;
    }
}

pub fn checkSpreadElement(tree: *const ast.Tree, element: ast.SpreadElement, state: *State) void {
    if (state.active and isStateReference(tree, element.argument, state)) {
        state.abandoned = true;
    }
}

const FirstParameter = struct {
    const Kind = enum { none, name, object_pattern };

    kind: Kind = .none,
    name: ?[]const u8 = null,
    node: ast.NodeIndex = .null,
};

fn firstParameter(_: Allocator, tree: *const ast.Tree, params_index: ast.NodeIndex) ?FirstParameter {
    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return null,
    };
    const items = tree.extra(params.items);
    if (items.len == 0) return null;
    const pattern = switch (tree.data(items[0])) {
        .formal_parameter => |parameter| parameter.pattern,
        else => items[0],
    };
    if (bindingIdentifierName(tree, pattern)) |name| return .{ .kind = .name, .name = name, .node = pattern };
    if (tree.data(unwrapTransparent(tree, pattern)) == .object_pattern) return .{ .kind = .object_pattern, .node = pattern };
    return .{};
}

fn handleAssignment(
    allocator: Allocator,
    tree: *const ast.Tree,
    left: ast.NodeIndex,
    right: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    if (assignmentTargetName(tree, left)) |name| {
        if (isStateReference(tree, right, state)) {
            try state.addAlias(allocator, name);
        }
        return;
    }

    if (tree.data(unwrapTransparent(tree, left)) == .object_pattern) {
        if (isStateReference(tree, right, state)) {
            try handleStateDestructuring(allocator, tree, left, state);
        } else if (tree.data(unwrapTransparent(tree, right)) == .this_expression) {
            try handleThisDestructuring(allocator, tree, left, state);
        }
    }
}

fn handleThisDestructuring(
    allocator: Allocator,
    tree: *const ast.Tree,
    pattern_index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    const pattern = switch (tree.data(unwrapTransparent(tree, pattern_index))) {
        .object_pattern => |pattern| pattern,
        else => return,
    };
    for (tree.extra(pattern.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .binding_property => |property| property,
            else => continue,
        };
        const key = propertyName(tree, property.key, property.computed) orelse continue;
        if (!std.mem.eql(u8, key, "state")) continue;
        if (bindingIdentifierName(tree, property.value)) |name| {
            try state.addAlias(allocator, name);
        } else {
            try handleStateDestructuring(allocator, tree, property.value, state);
        }
    }
}

fn handleStateDestructuring(
    allocator: Allocator,
    tree: *const ast.Tree,
    pattern_index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    const pattern = switch (tree.data(unwrapTransparent(tree, pattern_index))) {
        .object_pattern => |pattern| pattern,
        else => return,
    };
    for (tree.extra(pattern.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .binding_property => |property| property,
            else => continue,
        };
        const key = propertyName(tree, property.key, property.computed) orelse continue;
        try state.addUsedStateField(allocator, key);
    }
    if (pattern.rest != .null) {
        const rest = switch (tree.data(pattern.rest)) {
            .binding_rest_element => |rest| rest,
            else => return,
        };
        if (bindingIdentifierName(tree, rest.argument)) |name| {
            try state.addAlias(allocator, name);
        }
    }
}

fn addStateFieldsFromObject(
    allocator: Allocator,
    tree: *const ast.Tree,
    object: ast.ObjectExpression,
    state: *State,
) Allocator.Error!void {
    for (tree.extra(object.properties)) |property_index| {
        switch (tree.data(property_index)) {
            .object_property => |property| {
                const name = propertyName(tree, property.key, property.computed) orelse continue;
                try state.addStateField(allocator, name, property_index);
            },
            .spread_element => state.abandoned = true,
            else => {},
        }
    }
}

fn isStateReference(tree: *const ast.Tree, index: ast.NodeIndex, state: *const State) bool {
    const current = unwrapTransparent(tree, index);
    if (isThisStateMember(tree, current)) return true;
    if (identifierReferenceName(tree, current)) |name| {
        if (state.aliases_active and state.aliases.contains(name)) return true;
        if (state.state_param_name) |state_param| {
            if (std.mem.eql(u8, name, state_param)) return true;
        }
    }
    return false;
}

fn isThisStateMember(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const member = switch (tree.data(unwrapTransparent(tree, index))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (!isThisExpression(tree, member.object)) return false;
    const property = propertyName(tree, member.property, member.computed) orelse return false;
    return std.mem.eql(u8, property, "state");
}

fn isSetStateCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (!isThisExpression(tree, member.object)) return false;
    const property = propertyName(tree, member.property, member.computed) orelse return false;
    return std.mem.eql(u8, property, "setState");
}

fn lifecycleStateParameterName(tree: *const ast.Tree, method: ast.MethodDefinition) ?[]const u8 {
    const name = propertyName(tree, method.key, method.computed) orelse return null;
    const accepts_state = (method.static and std.mem.eql(u8, name, "getDerivedStateFromProps")) or
        std.mem.eql(u8, name, "shouldComponentUpdate") or
        std.mem.eql(u8, name, "componentWillUpdate") or
        std.mem.eql(u8, name, "UNSAFE_componentWillUpdate") or
        std.mem.eql(u8, name, "getSnapshotBeforeUpdate") or
        std.mem.eql(u8, name, "componentDidUpdate");
    if (!accepts_state) return null;

    const function = switch (tree.data(method.value)) {
        .function => |function| function,
        else => return null,
    };
    return nthParameterName(tree, function.params, 1);
}

fn nthParameterName(tree: *const ast.Tree, params_index: ast.NodeIndex, n: usize) ?[]const u8 {
    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return null,
    };
    const items = tree.extra(params.items);
    if (items.len <= n) return null;
    const pattern = switch (tree.data(items[n])) {
        .formal_parameter => |parameter| parameter.pattern,
        else => items[n],
    };
    return bindingIdentifierName(tree, pattern);
}

fn inConstructor(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        const method = switch (tree.data(ancestor)) {
            .method_definition => |method| method,
            else => continue,
        };
        return method.kind == .constructor;
    }
    return false;
}

fn returnArgument(tree: *const ast.Tree, function_index: ast.NodeIndex) ?ast.NodeIndex {
    switch (tree.data(unwrapTransparent(tree, function_index))) {
        .function => |function| return returnArgumentFromBody(tree, function.body),
        .arrow_function_expression => |arrow| return if (arrow.expression) arrow.body else returnArgumentFromBody(tree, arrow.body),
        else => return null,
    }
}

fn returnArgumentFromBody(tree: *const ast.Tree, body_index: ast.NodeIndex) ?ast.NodeIndex {
    if (body_index == .null) return null;
    const body = switch (tree.data(body_index)) {
        .function_body => |body| body.body,
        .block_statement => |block| block.body,
        else => return null,
    };
    var result: ?ast.NodeIndex = null;
    for (tree.extra(body)) |statement_index| {
        const statement = unwrapTransparent(tree, statement_index);
        switch (tree.data(statement)) {
            .return_statement => |return_statement| result = return_statement.argument,
            else => {},
        }
    }
    return result;
}

fn isCreateClassObject(tree: *const ast.Tree, index: ast.NodeIndex, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    const call = switch (tree.data(parent)) {
        .call_expression => |call| call,
        else => return false,
    };
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0 or arguments[0] != index) return false;
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createReactClass");
    }
    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    const property = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, property, "createClass");
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
    const property = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, property, "Component") or std.mem.eql(u8, property, "PureComponent");
}

fn isFunctionLike(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .function, .arrow_function_expression => true,
        else => false,
    };
}

fn isArrowFunctionExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .arrow_function_expression => true,
        else => false,
    };
}

fn objectExpression(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.ObjectExpression {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .object_expression => |object| object,
        else => null,
    };
}

fn isThisExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .this_expression => true,
        else => false,
    };
}

fn assignmentTargetName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return identifierReferenceName(tree, index) orelse bindingIdentifierName(tree, index);
}

fn nodeName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    const current = unwrapTransparent(tree, index);
    return switch (tree.data(current)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        .binding_identifier => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| if (tree.extra(literal.expressions).len == 0 and tree.extra(literal.quasis).len == 1)
            templateElementRaw(tree, tree.extra(literal.quasis)[0])
        else
            null,
        else => null,
    };
}

fn templateElementRaw(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (index == .null) return null;
    if (computed) {
        const current = unwrapTransparent(tree, index);
        return switch (tree.data(current)) {
            .string_literal => |literal| tree.string(literal.value),
            .template_literal => |literal| if (tree.extra(literal.expressions).len == 0 and tree.extra(literal.quasis).len == 1)
                templateElementRaw(tree, tree.extra(literal.quasis)[0])
            else
                null,
            else => null,
        };
    }
    return nodeName(tree, index);
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
            .ts_as_expression => |expression| current = expression.expression,
            .ts_satisfies_expression => |expression| current = expression.expression,
            .ts_non_null_expression => |expression| current = expression.expression,
            .ts_type_assertion => |assertion| current = assertion.expression,
            else => return current,
        }
    }
    return current;
}
