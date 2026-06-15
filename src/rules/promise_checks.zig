const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const no_async_promise_executor = @import("no_async_promise_executor.zig");
const no_promise_executor_return = @import("no_promise_executor_return.zig");
const prefer_promise_reject_errors = @import("prefer_promise_reject_errors.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    check_no_async_promise_executor: bool,
    check_no_promise_executor_return: bool,
    check_prefer_promise_reject_errors: bool,
) Allocator.Error!void {
    if (!check_no_async_promise_executor and
        !check_no_promise_executor_return and
        !check_prefer_promise_reject_errors) return;

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .check_no_async_promise_executor = check_no_async_promise_executor,
        .check_no_promise_executor_return = check_no_promise_executor_return,
        .check_prefer_promise_reject_errors = check_prefer_promise_reject_errors,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    check_no_async_promise_executor: bool,
    check_no_promise_executor_return: bool,
    check_prefer_promise_reject_errors: bool,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.check_prefer_promise_reject_errors and
            isGlobalPromiseRejectCall(ctx.tree, self.symbol_table, call))
        {
            try checkRejectArgument(self.allocator, self.diagnostics, ctx.tree, call.arguments, index);
        }

        return .proceed;
    }

    pub fn enter_new_expression(
        self: *Visitor,
        expression: ast.NewExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (!isGlobalPromiseReference(ctx.tree, self.symbol_table, expression.callee)) return .proceed;

        const executor = promiseExecutor(ctx.tree, expression.arguments);

        if (self.check_no_async_promise_executor and
            executor != null and
            isAsyncFunctionLike(ctx.tree, executor.?))
        {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                no_async_promise_executor.id,
                "Promise executor functions should not be async.",
                ctx.tree.span(index),
            );
        }

        if (self.check_no_promise_executor_return and executor != null) {
            try checkExecutorReturn(self.allocator, self.diagnostics, ctx.tree, executor.?);
        }

        if (self.check_prefer_promise_reject_errors and executor != null) {
            const reject_name = executorRejectName(ctx.tree, executor.?) orelse return .proceed;
            try scanExecutorRejects(self.allocator, self.diagnostics, ctx.tree, reject_name, executor.?);
        }

        return .proceed;
    }
};

fn isGlobalPromiseRejectCall(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    call: ast.CallExpression,
) bool {
    if (call.optional) return false;

    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.optional) return false;

    const property = staticMemberPropertyName(tree, member) orelse return false;
    if (!std.mem.eql(u8, property, "reject")) return false;
    return isGlobalPromiseReference(tree, symbol_table, member.object);
}

fn promiseExecutor(tree: *const ast.Tree, arguments: ast.IndexRange) ?ast.NodeIndex {
    if (arguments.len == 0) return null;

    const executor = unwrapTransparent(tree, tree.extra(arguments)[0]);
    return switch (tree.data(executor)) {
        .arrow_function_expression,
        .function,
        => executor,
        else => null,
    };
}

fn isAsyncFunctionLike(tree: *const ast.Tree, executor: ast.NodeIndex) bool {
    return switch (tree.data(executor)) {
        .arrow_function_expression => |arrow| arrow.async,
        .function => |function| function.async,
        else => false,
    };
}

fn checkExecutorReturn(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    executor: ast.NodeIndex,
) Allocator.Error!void {
    switch (tree.data(executor)) {
        .arrow_function_expression => |arrow| {
            if (arrow.expression) {
                try addPromiseReturnDiagnostic(allocator, diagnostics, tree, arrow.body);
            } else {
                try scanFunctionBodyForReturns(allocator, diagnostics, tree, arrow.body);
            }
        },
        .function => |function| try scanFunctionBodyForReturns(allocator, diagnostics, tree, function.body),
        else => {},
    }
}

fn scanFunctionBodyForReturns(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body_index: ast.NodeIndex,
) Allocator.Error!void {
    if (body_index == .null) return;

    const body = switch (tree.data(body_index)) {
        .function_body => |body| body,
        else => return,
    };

    try scanReturnRange(allocator, diagnostics, tree, body.body);
}

fn scanReturnNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .return_statement => |statement| {
            if (statement.argument != .null) {
                try addPromiseReturnDiagnostic(allocator, diagnostics, tree, index);
            }
        },
        .block_statement => |block| try scanReturnRange(allocator, diagnostics, tree, block.body),
        .static_block => |block| try scanReturnRange(allocator, diagnostics, tree, block.body),
        .if_statement => |statement| {
            try scanReturnNode(allocator, diagnostics, tree, statement.consequent);
            try scanReturnNode(allocator, diagnostics, tree, statement.alternate);
        },
        .switch_statement => |statement| {
            for (tree.extra(statement.cases)) |case_index| {
                const switch_case = switch (tree.data(case_index)) {
                    .switch_case => |switch_case| switch_case,
                    else => continue,
                };
                try scanReturnRange(allocator, diagnostics, tree, switch_case.consequent);
            }
        },
        .for_statement => |statement| try scanReturnNode(allocator, diagnostics, tree, statement.body),
        .for_in_statement => |statement| try scanReturnNode(allocator, diagnostics, tree, statement.body),
        .for_of_statement => |statement| try scanReturnNode(allocator, diagnostics, tree, statement.body),
        .while_statement => |statement| try scanReturnNode(allocator, diagnostics, tree, statement.body),
        .do_while_statement => |statement| try scanReturnNode(allocator, diagnostics, tree, statement.body),
        .with_statement => |statement| try scanReturnNode(allocator, diagnostics, tree, statement.body),
        .labeled_statement => |statement| try scanReturnNode(allocator, diagnostics, tree, statement.body),
        .try_statement => |statement| {
            try scanReturnNode(allocator, diagnostics, tree, statement.block);
            if (statement.handler != .null) {
                const handler = switch (tree.data(statement.handler)) {
                    .catch_clause => |handler| handler,
                    else => return,
                };
                try scanReturnNode(allocator, diagnostics, tree, handler.body);
            }
            try scanReturnNode(allocator, diagnostics, tree, statement.finalizer);
        },
        .function,
        .arrow_function_expression,
        .class,
        => return,
        else => return,
    }
}

fn scanReturnRange(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    range: ast.IndexRange,
) Allocator.Error!void {
    for (tree.extra(range)) |child| {
        try scanReturnNode(allocator, diagnostics, tree, child);
    }
}

fn addPromiseReturnDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        no_promise_executor_return.id,
        "Promise executor should not return a value.",
        tree.span(index),
    );
}

fn executorRejectName(tree: *const ast.Tree, executor: ast.NodeIndex) ?[]const u8 {
    const params_index = switch (tree.data(executor)) {
        .function => |function| function.params,
        .arrow_function_expression => |arrow| arrow.params,
        else => return null,
    };

    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return null,
    };

    const items = tree.extra(params.items);
    if (items.len < 2) return null;

    const second = switch (tree.data(items[1])) {
        .formal_parameter => |parameter| parameter.pattern,
        else => return null,
    };

    return bindingIdentifierName(tree, second);
}

fn scanExecutorRejects(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    reject_name: []const u8,
    executor: ast.NodeIndex,
) Allocator.Error!void {
    switch (tree.data(executor)) {
        .function => |function| try scanRejectNode(allocator, diagnostics, tree, reject_name, function.body),
        .arrow_function_expression => |arrow| try scanRejectNode(allocator, diagnostics, tree, reject_name, arrow.body),
        else => {},
    }
}

fn scanRejectNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    reject_name: []const u8,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .call_expression => |call| {
            if (isRejectCall(tree, reject_name, call)) {
                try checkRejectArgument(allocator, diagnostics, tree, call.arguments, index);
            }
            try scanRejectChildren(allocator, diagnostics, tree, reject_name, call);
        },
        .function,
        .arrow_function_expression,
        .class,
        => return,
        inline else => |node| try scanRejectChildren(allocator, diagnostics, tree, reject_name, node),
    }
}

fn scanRejectChildren(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    reject_name: []const u8,
    node: anytype,
) Allocator.Error!void {
    const T = @TypeOf(node);
    if (@typeInfo(T) != .@"struct") return;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (field.type == ast.NodeIndex) {
            try scanRejectNode(allocator, diagnostics, tree, reject_name, @field(node, field.name));
        } else if (field.type == ast.IndexRange) {
            for (tree.extra(@field(node, field.name))) |child| {
                try scanRejectNode(allocator, diagnostics, tree, reject_name, child);
            }
        }
    }
}

fn isRejectCall(tree: *const ast.Tree, reject_name: []const u8, call: ast.CallExpression) bool {
    if (call.optional) return false;
    return isIdentifierReferenceNamed(tree, call.callee, reject_name);
}

fn checkRejectArgument(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    arguments: ast.IndexRange,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (arguments.len == 0) return;
    const argument = tree.extra(arguments)[0];
    if (!isInvalidRejectReason(tree, unwrapTransparent(tree, argument))) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        prefer_promise_reject_errors.id,
        "Expected the Promise rejection reason to be an Error.",
        tree.span(index),
    );
}

fn isInvalidRejectReason(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .string_literal,
        .numeric_literal,
        .bigint_literal,
        .boolean_literal,
        .null_literal,
        .template_literal,
        => true,
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        .binary_expression => |expression| expression.operator == .add,
        else => false,
    };
}

fn isGlobalPromiseReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    if (!isIdentifierReferenceNamed(tree, unwrapped, "Promise")) return false;
    return isUnresolvedReference(symbol_table, unwrapped);
}

fn isUnresolvedReference(
    symbol_table: traverser.semantic.SymbolTable,
    node: ast.NodeIndex,
) bool {
    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        if (entry.reference.node == node) {
            return symbol_table.referenceSymbol(entry.id) == .none;
        }
    }

    return false;
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn staticMemberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| if (member.computed) null else tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";

    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
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
