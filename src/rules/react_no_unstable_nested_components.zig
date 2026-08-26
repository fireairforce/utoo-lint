const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/no-unstable-nested-components";

const message = "Do not define components during render. Move the component definition out of the parent component";

pub const Options = struct {
    allow_as_props: bool = false,
    prop_name_pattern: []const u8 = "render*",
};

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (function.body == .null or !functionReturnsJSXOrNull(tree, index)) return;
    try checkCandidate(allocator, diagnostics, tree, index, function.id, ctx, options);
}

pub fn checkArrowFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (!functionReturnsJSXOrNull(tree, index)) return;
    try checkCandidate(allocator, diagnostics, tree, index, .null, ctx, options);
}

fn checkCandidate(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    own_name_index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (isDirectCollectionCallback(tree, index, &ctx.path)) return;

    const prop_name = propNameFromAncestors(tree, &ctx.path);
    if (prop_name) |name| {
        if (propIsAllowed(name, options)) return;
    } else if (!hasComponentName(tree, index, own_name_index, &ctx.path, 0)) {
        return;
    }

    if (!hasEnclosingComponent(tree, &ctx.path)) return;
    try core.addDiagnostic(allocator, diagnostics, .warning, id, message, tree.span(index));
}

fn hasEnclosingComponent(tree: *const ast.Tree, path: *const traverser.NodePath) bool {
    var depth: usize = 1;
    while (path.ancestor(depth)) |ancestor_index| : (depth += 1) {
        switch (tree.data(ancestor_index)) {
            .function => |function| {
                if (isReactClassRenderMethod(tree, path, depth)) return true;
                if (function.body != .null and functionReturnsJSXOrNull(tree, ancestor_index) and
                    hasComponentName(tree, ancestor_index, function.id, path, depth))
                {
                    return true;
                }
            },
            .arrow_function_expression => {
                if (functionReturnsJSXOrNull(tree, ancestor_index) and
                    hasComponentName(tree, ancestor_index, .null, path, depth))
                {
                    return true;
                }
            },
            else => {},
        }
    }
    return false;
}

fn hasComponentName(
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    own_name_index: ast.NodeIndex,
    path: *const traverser.NodePath,
    depth: usize,
) bool {
    if (bindingIdentifierName(tree, own_name_index)) |name| {
        if (startsUppercase(name)) return true;
    }
    const assigned_name = assignedName(tree, index, path, depth + 1) orelse return false;
    return startsUppercase(assigned_name);
}

fn assignedName(
    tree: *const ast.Tree,
    start_index: ast.NodeIndex,
    path: *const traverser.NodePath,
    start_depth: usize,
) ?[]const u8 {
    var child = start_index;
    var depth = start_depth;
    while (path.ancestor(depth)) |parent_index| : (depth += 1) {
        switch (tree.data(parent_index)) {
            .chain_expression => |expression| {
                if (expression.expression != child) return null;
            },
            .parenthesized_expression => |expression| {
                if (expression.expression != child) return null;
            },
            .ts_as_expression => |expression| {
                if (expression.expression != child) return null;
            },
            .ts_satisfies_expression => |expression| {
                if (expression.expression != child) return null;
            },
            .ts_non_null_expression => |expression| {
                if (expression.expression != child) return null;
            },
            .ts_type_assertion => |expression| {
                if (expression.expression != child) return null;
            },
            .ts_instantiation_expression => |expression| {
                if (expression.expression != child) return null;
            },
            .call_expression => |call| {
                if (!isWrapperArgument(tree, call, child)) return null;
            },
            .variable_declarator => |declarator| {
                if (declarator.init != child) return null;
                return bindingIdentifierName(tree, declarator.id);
            },
            .assignment_expression => |expression| {
                if (expression.right != child) return null;
                return assignmentName(tree, expression.left);
            },
            .object_property => |property| {
                if (property.value != child) return null;
                return propertyName(tree, property.key, property.computed);
            },
            .export_default_declaration => return "Component",
            else => return null,
        }
        child = parent_index;
    }
    return null;
}

fn isWrapperArgument(tree: *const ast.Tree, call: ast.CallExpression, child: ast.NodeIndex) bool {
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0 or arguments[0] != child) return false;
    return !isCollectionCallbackCall(tree, call);
}

fn isDirectCollectionCallback(tree: *const ast.Tree, index: ast.NodeIndex, path: *const traverser.NodePath) bool {
    var child = index;
    var depth: usize = 1;
    while (path.ancestor(depth)) |parent_index| : (depth += 1) {
        switch (tree.data(parent_index)) {
            .chain_expression => |expression| if (expression.expression != child) return false,
            .parenthesized_expression => |expression| if (expression.expression != child) return false,
            .ts_as_expression => |expression| if (expression.expression != child) return false,
            .ts_satisfies_expression => |expression| if (expression.expression != child) return false,
            .ts_non_null_expression => |expression| if (expression.expression != child) return false,
            .ts_type_assertion => |expression| if (expression.expression != child) return false,
            .call_expression => |call| {
                const arguments = tree.extra(call.arguments);
                return arguments.len > 0 and arguments[0] == child and isCollectionCallbackCall(tree, call);
            },
            else => return false,
        }
        child = parent_index;
    }
    return false;
}

fn isCollectionCallbackCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    const name = propertyName(tree, member.property, member.computed) orelse return false;
    const methods = [_][]const u8{
        "every", "filter", "find", "findIndex", "flatMap", "forEach", "map", "reduce", "reduceRight", "some", "sort",
    };
    for (methods) |method| {
        if (std.mem.eql(u8, name, method)) return true;
    }
    return false;
}

fn propNameFromAncestors(tree: *const ast.Tree, path: *const traverser.NodePath) ?[]const u8 {
    var depth: usize = 1;
    while (path.ancestor(depth)) |ancestor_index| : (depth += 1) {
        switch (tree.data(ancestor_index)) {
            .jsx_attribute => |attribute| return jsxIdentifierName(tree, attribute.name),
            .object_property => |property| return propertyName(tree, property.key, property.computed),
            .function, .arrow_function_expression => return null,
            else => {},
        }
    }
    return null;
}

fn propIsAllowed(name: []const u8, options: Options) bool {
    if (options.allow_as_props) return true;
    if (std.mem.eql(u8, name, "children")) return true;
    return wildcardMatches(options.prop_name_pattern, name);
}

fn wildcardMatches(pattern: []const u8, value: []const u8) bool {
    var pattern_index: usize = 0;
    var value_index: usize = 0;
    var star_index: ?usize = null;
    var retry_value_index: usize = 0;

    while (value_index < value.len) {
        if (pattern_index < pattern.len and pattern[pattern_index] == value[value_index]) {
            pattern_index += 1;
            value_index += 1;
        } else if (pattern_index < pattern.len and pattern[pattern_index] == '*') {
            star_index = pattern_index;
            pattern_index += 1;
            retry_value_index = value_index;
        } else if (star_index) |star| {
            pattern_index = star + 1;
            retry_value_index += 1;
            value_index = retry_value_index;
        } else {
            return false;
        }
    }
    while (pattern_index < pattern.len and pattern[pattern_index] == '*') pattern_index += 1;
    return pattern_index == pattern.len;
}

fn isReactClassRenderMethod(tree: *const ast.Tree, path: *const traverser.NodePath, function_depth: usize) bool {
    const method_index = path.ancestor(function_depth + 1) orelse return false;
    const method = switch (tree.data(method_index)) {
        .method_definition => |method| method,
        else => return false,
    };
    const method_name = propertyName(tree, method.key, method.computed) orelse return false;
    if (!std.mem.eql(u8, method_name, "render")) return false;

    const class_body_index = path.ancestor(function_depth + 2) orelse return false;
    if (tree.data(class_body_index) != .class_body) return false;
    const class_index = path.ancestor(function_depth + 3) orelse return false;
    const class = switch (tree.data(class_index)) {
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
    const property = propertyName(tree, member.property, member.computed) orelse return false;
    return std.mem.eql(u8, property, "Component") or std.mem.eql(u8, property, "PureComponent");
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
        .function, .arrow_function_expression => false,
        else => false,
    };
}

fn isJSXOrNullValue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .jsx_element, .jsx_fragment, .null_literal => true,
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
    const property = propertyName(tree, member.property, member.computed) orelse return false;
    return std.mem.eql(u8, property, "createElement");
}

fn assignmentName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    const current = unwrapTransparent(tree, index);
    if (identifierReferenceName(tree, current)) |name| return name;
    const member = switch (tree.data(current)) {
        .member_expression => |member| member,
        else => return null,
    };
    return propertyName(tree, member.property, member.computed);
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

fn jsxIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
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

fn startsUppercase(name: []const u8) bool {
    return name.len > 0 and std.ascii.isUpper(name[0]);
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |expression| current = expression.expression,
            .parenthesized_expression => |expression| current = expression.expression,
            .ts_as_expression => |expression| current = expression.expression,
            .ts_satisfies_expression => |expression| current = expression.expression,
            .ts_non_null_expression => |expression| current = expression.expression,
            .ts_type_assertion => |expression| current = expression.expression,
            .ts_instantiation_expression => |expression| current = expression.expression,
            else => return current,
        }
    }
    return current;
}
