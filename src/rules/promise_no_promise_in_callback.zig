const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "promise/no-promise-in-callback";

pub const Options = struct {
    exempt_declarations: bool = false,
};

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (!isPromiseCall(tree, call)) return;
    if (isDirectlyReturned(tree, ctx)) return;
    if (!isInsideCallback(tree, ctx, options)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Avoid using promises inside of callbacks.",
        tree.span(call.callee),
    );
}

fn isPromiseCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = memberPropertyName(tree, member) orelse return false;

    if (std.mem.eql(u8, property, "then") or
        std.mem.eql(u8, property, "catch") or
        std.mem.eql(u8, property, "finally"))
    {
        return true;
    }

    const object = unwrapTransparent(tree, member.object);
    if (tree.data(object) == .call_expression) {
        return isPromiseCall(tree, tree.data(object).call_expression);
    }

    if (!identifierReferenceNamed(tree, object, "Promise")) return false;
    return isPromiseStatic(property) and !std.mem.eql(u8, property, "withResolvers");
}

fn isPromiseStatic(name: []const u8) bool {
    const statics = [_][]const u8{
        "all",
        "allSettled",
        "any",
        "race",
        "reject",
        "resolve",
    };
    for (statics) |static| {
        if (std.mem.eql(u8, name, static)) return true;
    }
    return false;
}

fn isDirectlyReturned(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.parent() orelse return false;
    return tree.data(parent) == .return_statement;
}

fn isInsideCallback(tree: *const ast.Tree, ctx: *traverser.basic.Ctx, options: Options) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .function => |function| {
                const supported = function.type == .function_expression or
                    (!options.exempt_declarations and function.type == .function_declaration);
                if (!supported or isPromiseHandler(tree, ctx, depth, ancestor)) continue;
                if (firstParameterIsError(tree, function.params)) return true;
            },
            .arrow_function_expression => |arrow| {
                if (isPromiseHandler(tree, ctx, depth, ancestor)) continue;
                if (firstParameterIsError(tree, arrow.params)) return true;
            },
            else => {},
        }
    }
    return false;
}

fn isPromiseHandler(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    function_depth: usize,
    function_index: ast.NodeIndex,
) bool {
    const parent_index = ctx.path.ancestor(function_depth + 1) orelse return false;
    const call = switch (tree.data(parent_index)) {
        .call_expression => |call| call,
        else => return false,
    };
    const arguments = tree.extra(call.arguments);
    var is_argument = false;
    for (arguments) |argument| {
        if (unwrapTransparent(tree, argument) == function_index) {
            is_argument = true;
            break;
        }
    }
    if (!is_argument) return false;

    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = memberPropertyName(tree, member) orelse return false;
    return std.mem.eql(u8, property, "then") or std.mem.eql(u8, property, "catch");
}

fn firstParameterIsError(tree: *const ast.Tree, params_index: ast.NodeIndex) bool {
    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return false,
    };
    const items = tree.extra(params.items);
    if (items.len == 0) return false;
    const pattern = switch (tree.data(items[0])) {
        .formal_parameter => |parameter| parameter.pattern,
        else => return false,
    };
    const name = bindingIdentifierName(tree, pattern) orelse return false;
    return std.mem.eql(u8, name, "err") or std.mem.eql(u8, name, "error");
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn memberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
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
