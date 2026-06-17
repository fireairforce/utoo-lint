const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/jsx-no-bind";

pub const Options = struct {
    allow_arrow_functions: bool = false,
    allow_functions: bool = false,
    allow_bind: bool = false,
    ignore_refs: bool = false,
    ignore_dom_components: bool = false,
};

const Violation = enum {
    bind_call,
    arrow_func,
    func,

    fn message(self: Violation) []const u8 {
        return switch (self) {
            .bind_call => "JSX props should not use .bind()",
            .arrow_func => "JSX props should not use arrow functions",
            .func => "JSX props should not use functions",
        };
    }
};

const Binding = struct {
    name: []const u8,
    violation: Violation,
};

const Scope = struct {
    bindings: std.ArrayList(Binding) = .empty,

    fn deinit(self: *Scope, allocator: Allocator) void {
        self.bindings.deinit(allocator);
    }
};

pub const State = struct {
    scopes: std.ArrayList(Scope) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        for (self.scopes.items) |*scope| {
            scope.deinit(allocator);
        }
        self.scopes.deinit(allocator);
    }
};

pub fn enterBlock(allocator: Allocator, state: *State) Allocator.Error!void {
    try state.scopes.append(allocator, .{});
}

pub fn exitBlock(allocator: Allocator, state: *State) void {
    if (state.scopes.pop()) |scope_value| {
        var scope = scope_value;
        scope.deinit(allocator);
    }
}

pub fn checkFunctionDeclaration(
    allocator: Allocator,
    tree: *const ast.Tree,
    function: ast.Function,
    state: *State,
) Allocator.Error!void {
    if (function.type != .function_declaration) return;
    if (state.scopes.items.len == 0) return;
    const name = bindingIdentifierName(tree, function.id) orelse return;
    try addBinding(allocator, state, name, .func);
}

pub fn checkVariableDeclarator(
    allocator: Allocator,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    parent_index: ?ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    if (declarator.init == .null) return;
    if (state.scopes.items.len == 0) return;

    const parent = parent_index orelse return;
    const declaration = switch (tree.data(parent)) {
        .variable_declaration => |declaration| declaration,
        else => return,
    };
    if (declaration.kind != .@"const") return;

    const violation = nodeViolationType(tree, declarator.init) orelse return;
    const name = bindingIdentifierName(tree, declarator.id) orelse return;
    try addBinding(allocator, state, name, violation);
}

pub fn checkJSXAttribute(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    attribute: ast.JSXAttribute,
    index: ast.NodeIndex,
    state: State,
    parent_index: ?ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (shouldIgnoreAttribute(tree, attribute, parent_index, options)) return;
    if (attribute.value == .null) return;
    const container = switch (tree.data(attribute.value)) {
        .jsx_expression_container => |container| container,
        else => return,
    };

    if (container.expression == .null) return;
    const expression = unwrapTransparent(tree, container.expression);
    if (identifierReferenceName(tree, expression)) |name| {
        if (findBinding(state, name)) |violation| {
            if (!shouldReportViolation(violation, options)) return;
            try report(allocator, diagnostics, tree, index, violation);
        }
        return;
    }

    const violation = nodeViolationType(tree, expression) orelse return;
    if (!shouldReportViolation(violation, options)) return;
    try report(allocator, diagnostics, tree, index, violation);
}

fn addBinding(
    allocator: Allocator,
    state: *State,
    name: []const u8,
    violation: Violation,
) Allocator.Error!void {
    const scope = &state.scopes.items[state.scopes.items.len - 1];
    try scope.bindings.append(allocator, .{ .name = name, .violation = violation });
}

fn findBinding(state: State, name: []const u8) ?Violation {
    var scope_index = state.scopes.items.len;
    while (scope_index > 0) {
        scope_index -= 1;
        const scope = state.scopes.items[scope_index];
        var binding_index = scope.bindings.items.len;
        while (binding_index > 0) {
            binding_index -= 1;
            const binding = scope.bindings.items[binding_index];
            if (std.mem.eql(u8, binding.name, name)) return binding.violation;
        }
    }
    return null;
}

fn shouldReportViolation(violation: Violation, options: Options) bool {
    return switch (violation) {
        .bind_call => !options.allow_bind,
        .arrow_func => !options.allow_arrow_functions,
        .func => !options.allow_functions,
    };
}

fn shouldIgnoreAttribute(tree: *const ast.Tree, attribute: ast.JSXAttribute, parent_index: ?ast.NodeIndex, options: Options) bool {
    if (options.ignore_refs) {
        if (jsxIdentifierName(tree, attribute.name)) |name| {
            if (std.mem.eql(u8, name, "ref")) return true;
        }
    }

    if (options.ignore_dom_components) {
        const opening = jsxOpeningElement(tree, parent_index) orelse return false;
        if (isDomComponent(tree, opening.name)) return true;
    }

    return false;
}

fn nodeViolationType(tree: *const ast.Tree, index: ast.NodeIndex) ?Violation {
    const current = unwrapTransparent(tree, index);
    return switch (tree.data(current)) {
        .call_expression => |call| if (isBindCall(tree, call)) .bind_call else null,
        .conditional_expression => |conditional| nodeViolationType(tree, conditional.@"test") orelse
            nodeViolationType(tree, conditional.consequent) orelse
            nodeViolationType(tree, conditional.alternate),
        .arrow_function_expression => .arrow_func,
        .function => |function| switch (function.type) {
            .function_declaration,
            .function_expression,
            => .func,
            else => null,
        },
        else => null,
    };
}

fn jsxOpeningElement(tree: *const ast.Tree, parent_index: ?ast.NodeIndex) ?ast.JSXOpeningElement {
    const parent = parent_index orelse return null;
    return switch (tree.data(parent)) {
        .jsx_opening_element => |opening| opening,
        else => null,
    };
}

fn isDomComponent(tree: *const ast.Tree, name_index: ast.NodeIndex) bool {
    const name = jsxIdentifierName(tree, name_index) orelse return false;
    return name.len > 0 and std.ascii.isLower(name[0]);
}

fn jsxIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isBindCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member) orelse return false;
    return std.mem.eql(u8, property, "bind");
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.computed or member.property == .null) return null;
    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    violation: Violation,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        violation.message(),
        tree.span(index),
    );
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
