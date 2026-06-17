const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/display-name";

const message = "Component definition is missing display name";

pub const Options = struct {
    check_context_objects: bool = false,
    ignore_transpiler_name: bool = false,
};

const Component = struct {
    node: ast.NodeIndex,
    name: ?[]const u8,
    has_display_name: bool,
};

pub const State = struct {
    components: std.ArrayList(Component) = .empty,
    declared_display_names: std.ArrayList([]const u8) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.components.deinit(allocator);
        self.declared_display_names.deinit(allocator);
        self.* = .{};
    }

    fn addComponent(self: *State, allocator: Allocator, component: Component) Allocator.Error!void {
        for (self.components.items) |existing| {
            if (existing.node == component.node) return;
        }
        var next = component;
        if (!next.has_display_name) {
            if (next.name) |name| {
                next.has_display_name = self.hasDeclaredDisplayName(name);
            }
        }
        try self.components.append(allocator, next);
    }

    fn markNode(self: *State, node: ast.NodeIndex) void {
        for (self.components.items) |*component| {
            if (component.node == node) {
                component.has_display_name = true;
                return;
            }
        }
    }

    fn markName(self: *State, allocator: Allocator, name: []const u8) Allocator.Error!void {
        if (!self.hasDeclaredDisplayName(name)) {
            try self.declared_display_names.append(allocator, name);
        }
        for (self.components.items) |*component| {
            if (component.name) |component_name| {
                if (std.mem.eql(u8, component_name, name)) {
                    component.has_display_name = true;
                }
            }
        }
    }

    fn hasDeclaredDisplayName(self: *const State, name: []const u8) bool {
        for (self.declared_display_names.items) |declared| {
            if (std.mem.eql(u8, declared, name)) return true;
        }
        return false;
    }
};

pub fn checkClass(
    allocator: Allocator,
    tree: *const ast.Tree,
    class: ast.Class,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (!isReactComponentClass(tree, class)) return;
    const name = componentNameFromClass(tree, class, parent_index);
    try state.addComponent(allocator, .{
        .node = index,
        .name = name,
        .has_display_name = (!options.ignore_transpiler_name and name != null) or classHasStaticDisplayName(tree, class),
    });
}

pub fn checkFunction(
    allocator: Allocator,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (!functionReturnsJSXOrNull(tree, index)) return;
    if (!isFunctionComponent(tree, function, parent_index)) return;
    const name = componentNameFromFunction(tree, function, parent_index);
    try state.addComponent(allocator, .{
        .node = index,
        .name = name,
        .has_display_name = !options.ignore_transpiler_name and name != null,
    });
}

pub fn checkArrowFunction(
    allocator: Allocator,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (!functionReturnsJSXOrNull(tree, index)) return;
    if (!functionExpressionHasComponentParent(tree, parent_index)) return;
    const name = componentNameFromParent(tree, parent_index);
    try state.addComponent(allocator, .{
        .node = index,
        .name = name,
        .has_display_name = !options.ignore_transpiler_name and name != null,
    });
}

pub fn checkCallExpression(
    allocator: Allocator,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (isCreateClassCall(tree, call)) {
        const arguments = tree.extra(call.arguments);
        if (arguments.len == 0) return;
        const object_index = unwrapTransparent(tree, arguments[0]);
        const object = switch (tree.data(object_index)) {
            .object_expression => |object| object,
            else => return,
        };
        const name = componentNameFromParent(tree, parent_index);
        try state.addComponent(allocator, .{
            .node = object_index,
            .name = name,
            .has_display_name = (!options.ignore_transpiler_name and name != null) or objectHasDisplayName(tree, object),
        });
        return;
    }

    if (!isComponentWrapperCall(tree, call)) return;
    if (isNestedWrapperCall(tree, index, parent_index)) return;
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return;
    if (!wrapperArgumentIsComponent(tree, arguments[0])) return;
    const name = componentNameFromParent(tree, parent_index);
    try state.addComponent(allocator, .{
        .node = index,
        .name = name,
        .has_display_name = !options.ignore_transpiler_name and name != null,
    });
}

pub fn checkMemberExpression(allocator: Allocator, tree: *const ast.Tree, member: ast.MemberExpression, state: *State) Allocator.Error!void {
    const property = propertyName(tree, member.property, member.computed) orelse return;
    if (!std.mem.eql(u8, property, "displayName")) return;
    if (identifierReferenceName(tree, unwrapTransparent(tree, member.object))) |name| {
        try state.markName(allocator, name);
    }
}

pub fn checkVariableDeclarator(
    allocator: Allocator,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    index: ast.NodeIndex,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (!options.check_context_objects) return;
    if (declarator.init == .null) return;
    const name = bindingIdentifierName(tree, declarator.id) orelse return;
    const call = switch (tree.data(unwrapTransparent(tree, declarator.init))) {
        .call_expression => |call| call,
        else => return,
    };
    if (!isCreateContextCall(tree, call)) return;

    try state.addComponent(allocator, .{
        .node = index,
        .name = name,
        .has_display_name = false,
    });
}

pub fn finish(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    state: *State,
) Allocator.Error!void {
    for (state.components.items) |component| {
        if (component.has_display_name) continue;
        try core.addDiagnostic(allocator, diagnostics, .warning, id, message, tree.span(component.node));
    }
}

fn componentNameFromClass(tree: *const ast.Tree, class: ast.Class, parent_index: ?ast.NodeIndex) ?[]const u8 {
    if (bindingIdentifierName(tree, class.id)) |name| return name;
    return componentNameFromParent(tree, parent_index);
}

fn componentNameFromFunction(tree: *const ast.Tree, function: ast.Function, parent_index: ?ast.NodeIndex) ?[]const u8 {
    if (bindingIdentifierName(tree, function.id)) |name| return name;
    return componentNameFromParent(tree, parent_index);
}

fn componentNameFromParent(tree: *const ast.Tree, parent_index: ?ast.NodeIndex) ?[]const u8 {
    const parent = parent_index orelse return null;
    return switch (tree.data(parent)) {
        .variable_declarator => |declarator| bindingIdentifierName(tree, declarator.id),
        .assignment_expression => |expression| assignmentName(tree, expression.left),
        .object_property => |property| propertyName(tree, property.key, property.computed),
        else => null,
    };
}

fn assignmentName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    const current = unwrapTransparent(tree, index);
    if (identifierReferenceName(tree, current)) |name| return name;
    const member = switch (tree.data(current)) {
        .member_expression => |member| member,
        else => return null,
    };
    if (isModuleExports(tree, member)) return null;
    return propertyName(tree, member.property, member.computed);
}

fn isFunctionComponent(tree: *const ast.Tree, function: ast.Function, parent_index: ?ast.NodeIndex) bool {
    if (function.async and function.generator) return false;
    if (function.type == .function_declaration) {
        const name = bindingIdentifierName(tree, function.id) orelse return true;
        return startsUppercase(name);
    }
    return functionExpressionHasComponentParent(tree, parent_index);
}

fn functionExpressionHasComponentParent(tree: *const ast.Tree, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    return switch (tree.data(parent)) {
        .variable_declarator => |declarator| identifierBindingStartsUppercase(tree, declarator.id),
        .assignment_expression => |expression| identifierReferenceStartsUppercase(tree, expression.left),
        .export_default_declaration => true,
        .object_property => |property| if (propertyName(tree, property.key, property.computed)) |name| startsUppercase(name) else false,
        else => false,
    };
}

fn wrapperArgumentIsComponent(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const current = unwrapTransparent(tree, index);
    return switch (tree.data(current)) {
        .function, .arrow_function_expression => functionReturnsJSXOrNull(tree, current),
        .call_expression => |call| isComponentWrapperCall(tree, call),
        else => false,
    };
}

fn isNestedWrapperCall(tree: *const ast.Tree, index: ast.NodeIndex, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    const call = switch (tree.data(parent)) {
        .call_expression => |call| call,
        else => return false,
    };
    const arguments = tree.extra(call.arguments);
    return arguments.len > 0 and unwrapTransparent(tree, arguments[0]) == index and isComponentWrapperCall(tree, call);
}

fn classHasStaticDisplayName(tree: *const ast.Tree, class: ast.Class) bool {
    const body = switch (tree.data(class.body)) {
        .class_body => |body| body,
        else => return false,
    };
    for (tree.extra(body.body)) |member_index| {
        switch (tree.data(member_index)) {
            .property_definition => |property| {
                if (!property.static) continue;
                const name = propertyName(tree, property.key, property.computed) orelse continue;
                if (std.mem.eql(u8, name, "displayName")) return true;
            },
            .method_definition => |method| {
                if (!method.static) continue;
                const name = propertyName(tree, method.key, method.computed) orelse continue;
                if (std.mem.eql(u8, name, "displayName")) return true;
            },
            else => {},
        }
    }
    return false;
}

fn objectHasDisplayName(tree: *const ast.Tree, object: ast.ObjectExpression) bool {
    for (tree.extra(object.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        const name = propertyName(tree, property.key, property.computed) orelse continue;
        if (std.mem.eql(u8, name, "displayName")) return true;
    }
    return false;
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

fn isCreateClassCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
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

fn isComponentWrapperCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "memo") or std.mem.eql(u8, name, "forwardRef");
    }
    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    const property = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, property, "memo") or std.mem.eql(u8, property, "forwardRef");
}

fn isCreateContextCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createContext");
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    const object = identifierReferenceName(tree, unwrapTransparent(tree, member.object)) orelse return false;
    if (!std.mem.eql(u8, object, "React")) return false;
    const property = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, property, "createContext");
}

fn functionReturnsJSXOrNull(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .function => |function| function.body != .null and bodyReturnsJSXOrNull(tree, function.body),
        .arrow_function_expression => |arrow| if (arrow.expression)
            isJSXOrNullValue(tree, arrow.body)
        else
            bodyReturnsJSXOrNull(tree, arrow.body),
        else => false,
    };
}

fn bodyReturnsJSXOrNull(tree: *const ast.Tree, body_index: ast.NodeIndex) bool {
    const range = switch (tree.data(body_index)) {
        .function_body => |body| body.body,
        .block_statement => |block| block.body,
        else => return false,
    };
    return rangeReturnsJSXOrNull(tree, range);
}

fn rangeReturnsJSXOrNull(tree: *const ast.Tree, range: ast.IndexRange) bool {
    for (tree.extra(range)) |statement_index| {
        if (statementReturnsJSXOrNull(tree, statement_index)) return true;
    }
    return false;
}

fn statementReturnsJSXOrNull(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .return_statement => |statement| isJSXOrNullValue(tree, statement.argument),
        .block_statement => |block| rangeReturnsJSXOrNull(tree, block.body),
        .if_statement => |statement| statementReturnsJSXOrNull(tree, statement.consequent) or
            statementReturnsJSXOrNull(tree, statement.alternate),
        .switch_statement => |statement| {
            for (tree.extra(statement.cases)) |case_index| {
                const case = switch (tree.data(case_index)) {
                    .switch_case => |case| case,
                    else => continue,
                };
                if (rangeReturnsJSXOrNull(tree, case.consequent)) return true;
            }
            return false;
        },
        .function,
        .arrow_function_expression,
        => false,
        else => false,
    };
}

fn isJSXOrNullValue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .jsx_element,
        .jsx_fragment,
        .null_literal,
        => true,
        .call_expression => |call| isCreateElementCall(tree, call),
        .conditional_expression => |conditional| isJSXOrNullValue(tree, conditional.consequent) or
            isJSXOrNullValue(tree, conditional.alternate),
        .logical_expression => |logical| isJSXOrNullValue(tree, logical.left) or isJSXOrNullValue(tree, logical.right),
        .sequence_expression => |sequence| {
            if (sequence.expressions.len == 0) return false;
            const items = tree.extra(sequence.expressions);
            return isJSXOrNullValue(tree, items[items.len - 1]);
        },
        else => false,
    };
}

fn isCreateElementCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createElement");
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    const property = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, property, "createElement");
}

fn isModuleExports(tree: *const ast.Tree, member: ast.MemberExpression) bool {
    if (!isIdentifierReferenceNamed(tree, member.object, "module")) return false;
    const property = propertyName(tree, member.property, member.computed) orelse return false;
    return std.mem.eql(u8, property, "exports");
}

fn identifierBindingStartsUppercase(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const name = bindingIdentifierName(tree, unwrapTransparent(tree, index)) orelse return false;
    return startsUppercase(name);
}

fn identifierReferenceStartsUppercase(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const name = identifierReferenceName(tree, unwrapTransparent(tree, index)) orelse return false;
    return startsUppercase(name);
}

fn startsUppercase(name: []const u8) bool {
    return name.len > 0 and std.ascii.isUpper(name[0]);
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (index == .null or computed) return null;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    const name = identifierReferenceName(tree, unwrapTransparent(tree, index)) orelse return false;
    return std.mem.eql(u8, name, expected);
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
