const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const jest_fn_call = @import("jest_fn_call.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;
const NodeSet = std.AutoHashMapUnmanaged(ast.NodeIndex, void);

pub const id = "jest/valid-describe-callback";

const name_and_callback_message = "Describe requires name and callback arguments";
const function_message = "Second argument must be function";
const async_message = "No async describe callback";
const argument_message = "Unexpected argument(s) in describe callback";
const return_message = "Unexpected return statement in describe callback";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    global_aliases: core.JestGlobalAliases,
) Allocator.Error!void {
    var resolver = try jest_fn_call.Resolver.init(allocator, tree, symbol_table, global_aliases);
    defer resolver.deinit();

    var describe_callbacks: NodeSet = .empty;
    defer describe_callbacks.deinit(allocator);

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .resolver = &resolver,
        .describe_callbacks = &describe_callbacks,
    };
    defer visitor.function_stack.deinit(allocator);
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    resolver: *const jest_fn_call.Resolver,
    describe_callbacks: *NodeSet,
    function_stack: std.ArrayList(bool) = .empty,

    pub fn enter_call_expression(
        self: *Visitor,
        call_expression: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const call = self.resolver.parseCall(call_expression, index, ctx.path.parent()) orelse return .proceed;
        if (call.function.kind() != .describe) return .proceed;

        const arguments = ctx.tree.extra(call_expression.arguments);
        if (arguments.len == 0) {
            try self.report(name_and_callback_message, ctx.tree.span(index));
            return .proceed;
        }
        if (arguments.len == 1) {
            try self.report(name_and_callback_message, argumentsSpan(ctx.tree, arguments));
            return .proceed;
        }

        const callback_index = unwrapTransparent(ctx.tree, arguments[1]);
        const callback = callbackInfo(ctx.tree, callback_index) orelse {
            try self.report(function_message, argumentsSpan(ctx.tree, arguments));
            return .proceed;
        };
        try self.describe_callbacks.put(self.allocator, callback_index, {});

        if (callback.async) {
            try self.report(async_message, ctx.tree.span(callback_index));
        }
        if (call.memberNamed("each") == null) {
            if (parametersSpan(ctx.tree, callback.params)) |span| {
                try self.report(argument_message, span);
            }
        }
        if (callback.returned_expression) {
            try self.report(return_message, ctx.tree.span(callback_index));
        }

        return .proceed;
    }

    pub fn enter_function(
        self: *Visitor,
        _: ast.Function,
        index: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.function_stack.append(self.allocator, self.describe_callbacks.contains(index));
        return .proceed;
    }

    pub fn exit_function(self: *Visitor, _: ast.Function, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        _ = self.function_stack.pop();
    }

    pub fn enter_arrow_function_expression(
        self: *Visitor,
        _: ast.ArrowFunctionExpression,
        index: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.function_stack.append(self.allocator, self.describe_callbacks.contains(index));
        return .proceed;
    }

    pub fn exit_arrow_function_expression(
        self: *Visitor,
        _: ast.ArrowFunctionExpression,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        _ = self.function_stack.pop();
    }

    pub fn enter_return_statement(
        self: *Visitor,
        _: ast.ReturnStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.function_stack.items.len == 0) return .proceed;
        if (self.function_stack.items[self.function_stack.items.len - 1]) {
            try self.report(return_message, ctx.tree.span(index));
        }
        return .proceed;
    }

    fn report(self: *Visitor, diagnostic_message: []const u8, span: ast.Span) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            diagnostic_message,
            span,
        );
    }
};

const CallbackInfo = struct {
    params: ast.NodeIndex,
    async: bool,
    returned_expression: bool,
};

fn callbackInfo(tree: *const ast.Tree, index: ast.NodeIndex) ?CallbackInfo {
    return switch (tree.data(index)) {
        .function => |function| if (function.type == .function_expression) .{
            .params = function.params,
            .async = function.async,
            .returned_expression = false,
        } else null,
        .arrow_function_expression => |arrow| .{
            .params = arrow.params,
            .async = arrow.async,
            .returned_expression = arrow.expression,
        },
        else => null,
    };
}

fn argumentsSpan(tree: *const ast.Tree, arguments: []const ast.NodeIndex) ast.Span {
    const first = tree.span(arguments[0]);
    const last = tree.span(arguments[arguments.len - 1]);
    return .{ .start = first.start, .end = last.end };
}

fn parametersSpan(tree: *const ast.Tree, params_index: ast.NodeIndex) ?ast.Span {
    const params = switch (tree.data(params_index)) {
        .formal_parameters => |value| value,
        else => return null,
    };
    const items = tree.extra(params.items);
    if (items.len == 0 and params.rest == .null) return null;

    const first_index = if (items.len > 0) items[0] else params.rest;
    const last_index = if (params.rest != .null) params.rest else items[items.len - 1];
    const first = tree.span(first_index);
    const last = tree.span(last_index);
    return .{ .start = first.start, .end = last.end };
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
            else => return current,
        }
    }
    return current;
}
