const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-multi-comp";

pub const State = struct {
    component_count: usize = 0,
};

pub const Options = struct {
    ignore_stateless: bool = true,
};

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    if (!isReactComponentClass(tree, class)) return;
    try reportComponent(allocator, diagnostics, tree, index, state);
}

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (options.ignore_stateless) return;
    if (function.type != .function_declaration) return;
    if (!functionNameStartsUppercase(tree, function)) return;
    if (!functionReturnsJSXOrNull(tree, index)) return;
    try reportComponent(allocator, diagnostics, tree, index, state);
}

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    index: ast.NodeIndex,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (options.ignore_stateless) return;
    if (!bindingIdentifierStartsUppercase(tree, declarator.id)) return;
    if (declarator.init == .null) return;
    if (!functionReturnsJSXOrNull(tree, declarator.init)) return;
    try reportComponent(allocator, diagnostics, tree, index, state);
}

fn reportComponent(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    state.component_count += 1;
    if (state.component_count <= 1) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Declare only one React component per file",
        tree.span(index),
    );
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
    if (!isIdentifierReferenceNamed(tree, unwrapTransparent(tree, member.object), "React")) return false;
    const property = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, property, "Component") or std.mem.eql(u8, property, "PureComponent");
}

fn functionNameStartsUppercase(tree: *const ast.Tree, function: ast.Function) bool {
    const name = bindingIdentifierName(tree, function.id) orelse return true;
    return startsUppercase(name);
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

fn bindingIdentifierStartsUppercase(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const name = bindingIdentifierName(tree, index) orelse return false;
    return startsUppercase(name);
}

fn startsUppercase(name: []const u8) bool {
    return name.len > 0 and std.ascii.isUpper(name[0]);
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (computed) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
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
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
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
