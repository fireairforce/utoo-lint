const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-useless-constructor";

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
) Allocator.Error!void {
    const body = switch (tree.data(class.body)) {
        .class_body => |body| body,
        else => return,
    };

    for (tree.extra(body.body)) |member_index| {
        const method = switch (tree.data(member_index)) {
            .method_definition => |method| method,
            else => continue,
        };
        if (!isUselessConstructor(tree, class, method)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Useless constructor.",
            tree.span(member_index),
        );
    }
}

pub fn isUselessConstructor(tree: *const ast.Tree, class: ast.Class, method: ast.MethodDefinition) bool {
    if (method.kind != .constructor) return false;
    if (method.static) return false;
    if (method.decorators.len != 0) return false;
    if (hasUsefulAccessibility(class, method)) return false;

    const function = switch (tree.data(method.value)) {
        .function => |function| function,
        else => return false,
    };
    if (function.body == .null) return false;
    if (hasParameterPropertyOrDecorators(tree, function.params)) return false;

    const body = switch (tree.data(function.body)) {
        .function_body => |body| body,
        else => return false,
    };

    if (class.super_class == .null) {
        return body.body.len == 0;
    }

    return isRedundantSuperCall(tree, body, function.params);
}

fn hasUsefulAccessibility(class: ast.Class, method: ast.MethodDefinition) bool {
    return switch (method.accessibility) {
        .private, .protected => true,
        .public => class.super_class != .null,
        .none => false,
    };
}

fn hasParameterPropertyOrDecorators(tree: *const ast.Tree, params_index: ast.NodeIndex) bool {
    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return false,
    };

    for (tree.extra(params.items)) |item_index| {
        switch (tree.data(item_index)) {
            .formal_parameter => |parameter| {
                if (hasPatternDecorators(tree, parameter.pattern)) return true;
            },
            .ts_parameter_property => return true,
            else => {},
        }
    }

    return hasPatternDecorators(tree, params.rest);
}

fn hasPatternDecorators(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .binding_identifier => |identifier| identifier.decorators.len != 0,
        .assignment_pattern => |pattern| pattern.decorators.len != 0 or hasPatternDecorators(tree, pattern.left),
        .binding_rest_element => |element| element.decorators.len != 0 or hasPatternDecorators(tree, element.argument),
        .array_pattern => |pattern| pattern.decorators.len != 0,
        .object_pattern => |pattern| pattern.decorators.len != 0,
        else => false,
    };
}

fn isRedundantSuperCall(tree: *const ast.Tree, body: ast.FunctionBody, params_index: ast.NodeIndex) bool {
    const statements = tree.extra(body.body);
    if (statements.len != 1) return false;

    const statement = switch (tree.data(statements[0])) {
        .expression_statement => |statement| statement,
        else => return false,
    };

    const call = switch (tree.data(unwrapTransparent(tree, statement.expression))) {
        .call_expression => |call| call,
        else => return false,
    };
    if (tree.data(unwrapTransparent(tree, call.callee)) != .super) return false;

    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return false,
    };
    if (!allParamsSimple(tree, params)) return false;

    const arguments = tree.extra(call.arguments);
    if (isSpreadArguments(tree, arguments)) return true;

    return isPassingThrough(tree, params, arguments);
}

fn allParamsSimple(tree: *const ast.Tree, params: ast.FormalParameters) bool {
    for (tree.extra(params.items)) |item_index| {
        const pattern = formalParameterPattern(tree, item_index) orelse return false;
        if (!isSimpleParameter(tree, pattern)) return false;
    }

    return params.rest == .null or isSimpleParameter(tree, params.rest);
}

fn isPassingThrough(tree: *const ast.Tree, params: ast.FormalParameters, arguments: []const ast.NodeIndex) bool {
    const params_len = params.items.len + @as(usize, if (params.rest == .null) 0 else 1);
    if (params_len != arguments.len) return false;

    var argument_index: usize = 0;
    for (tree.extra(params.items)) |item_index| {
        const pattern = formalParameterPattern(tree, item_index) orelse return false;
        if (!isValidPair(tree, pattern, arguments[argument_index])) return false;
        argument_index += 1;
    }

    if (params.rest != .null and !isValidPair(tree, params.rest, arguments[argument_index])) return false;
    return true;
}

fn formalParameterPattern(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    return switch (tree.data(index)) {
        .formal_parameter => |parameter| parameter.pattern,
        else => null,
    };
}

fn isSimpleParameter(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .binding_identifier => true,
        .binding_rest_element => |element| switch (tree.data(element.argument)) {
            .binding_identifier => true,
            else => false,
        },
        else => false,
    };
}

fn isSpreadArguments(tree: *const ast.Tree, arguments: []const ast.NodeIndex) bool {
    if (arguments.len != 1) return false;

    const spread = switch (tree.data(arguments[0])) {
        .spread_element => |spread| spread,
        else => return false,
    };

    return isIdentifierReferenceNamed(tree, spread.argument, "arguments");
}

fn isValidPair(tree: *const ast.Tree, param: ast.NodeIndex, argument: ast.NodeIndex) bool {
    if (isBindingReferencePair(tree, param, argument)) return true;

    const rest = switch (tree.data(param)) {
        .binding_rest_element => |rest| rest,
        else => return false,
    };
    const spread = switch (tree.data(argument)) {
        .spread_element => |spread| spread,
        else => return false,
    };

    return isBindingReferencePair(tree, rest.argument, spread.argument);
}

fn isBindingReferencePair(tree: *const ast.Tree, binding: ast.NodeIndex, reference: ast.NodeIndex) bool {
    const binding_name = switch (tree.data(binding)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => return false,
    };

    return isIdentifierReferenceNamed(tree, reference, binding_name);
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
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
