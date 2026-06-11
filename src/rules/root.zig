const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const no_alert = @import("no_alert.zig");
pub const eqeqeq = @import("eqeqeq.zig");
pub const no_array_constructor = @import("no_array_constructor.zig");
pub const no_caller = @import("no_caller.zig");
pub const no_compare_neg_zero = @import("no_compare_neg_zero.zig");
pub const no_comma_operator = @import("no_comma_operator.zig");
pub const no_console = @import("no_console.zig");
pub const no_debugger = @import("no_debugger.zig");
pub const no_delete_var = @import("no_delete_var.zig");
pub const no_empty_block_statements = @import("no_empty_block_statements.zig");
pub const no_for_in = @import("no_for_in.zig");
pub const no_global_is_finite = @import("no_global_is_finite.zig");
pub const no_global_is_nan = @import("no_global_is_nan.zig");
pub const no_new_func = @import("no_new_func.zig");
pub const no_new_object = @import("no_new_object.zig");
pub const no_new_symbol = @import("no_new_symbol.zig");
pub const no_new_wrappers = @import("no_new_wrappers.zig");
pub const no_proto = @import("no_proto.zig");
pub const no_self_compare = @import("no_self_compare.zig");
pub const no_sparse_arrays = @import("no_sparse_arrays.zig");
pub const no_unsafe_negation = @import("no_unsafe_negation.zig");
pub const no_undef = @import("no_undef.zig");
pub const no_unused_vars = @import("no_unused_vars.zig");
pub const no_var = @import("no_var.zig");
pub const no_void = @import("no_void.zig");
pub const no_with = @import("no_with.zig");

pub fn runBasic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    options: core.Options,
) Allocator.Error!void {
    var visitor = BasicVisitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .options = options,
    };

    try traverser.basic.traverse(BasicVisitor, tree, &visitor);
}

pub fn runSemantic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    semantic_result: traverser.semantic.Result,
    options: core.Options,
) Allocator.Error!void {
    if (options.no_array_constructor) {
        try no_array_constructor.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_alert) {
        try no_alert.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_global_is_finite) {
        try no_global_is_finite.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_global_is_nan) {
        try no_global_is_nan.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_func) {
        try no_new_func.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_object) {
        try no_new_object.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_symbol) {
        try no_new_symbol.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_wrappers) {
        try no_new_wrappers.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_unused_vars) {
        try no_unused_vars.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_undef) {
        try no_undef.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }
}

const BasicVisitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    options: core.Options,

    pub fn enter_debugger_statement(
        self: *BasicVisitor,
        _: ast.DebuggerStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_debugger) {
            try no_debugger.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_for_in_statement(
        self: *BasicVisitor,
        _: ast.ForInStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_for_in) {
            try no_for_in.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_block_statement(
        self: *BasicVisitor,
        block: ast.BlockStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_empty_block_statements) {
            try no_empty_block_statements.checkBlockStatement(self.allocator, self.diagnostics, ctx.tree, block, index);
        }
        return .proceed;
    }

    pub fn enter_function_body(
        self: *BasicVisitor,
        body: ast.FunctionBody,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_empty_block_statements) {
            try no_empty_block_statements.checkFunctionBody(self.allocator, self.diagnostics, ctx.tree, body, index);
        }
        return .proceed;
    }

    pub fn enter_static_block(
        self: *BasicVisitor,
        block: ast.StaticBlock,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_empty_block_statements) {
            try no_empty_block_statements.checkStaticBlock(self.allocator, self.diagnostics, ctx.tree, block, index);
        }
        return .proceed;
    }

    pub fn enter_with_statement(
        self: *BasicVisitor,
        _: ast.WithStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_with) {
            try no_with.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_variable_declaration(
        self: *BasicVisitor,
        declaration: ast.VariableDeclaration,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_var) {
            try no_var.check(self.allocator, self.diagnostics, ctx.tree, declaration, index);
        }
        return .proceed;
    }

    pub fn enter_binary_expression(
        self: *BasicVisitor,
        expression: ast.BinaryExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_compare_neg_zero) {
            try no_compare_neg_zero.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.eqeqeq) {
            try eqeqeq.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_self_compare) {
            try no_self_compare.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_unsafe_negation) {
            try no_unsafe_negation.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        return .proceed;
    }

    pub fn enter_unary_expression(
        self: *BasicVisitor,
        expression: ast.UnaryExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_delete_var) {
            try no_delete_var.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_void) {
            try no_void.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        return .proceed;
    }

    pub fn enter_sequence_expression(
        self: *BasicVisitor,
        expression: ast.SequenceExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_comma_operator) {
            try no_comma_operator.check(self.allocator, self.diagnostics, ctx.tree, expression, index, ctx);
        }
        return .proceed;
    }

    pub fn enter_call_expression(
        self: *BasicVisitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_console) {
            try no_console.check(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        return .proceed;
    }

    pub fn enter_member_expression(
        self: *BasicVisitor,
        member: ast.MemberExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_caller) {
            try no_caller.check(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
        if (self.options.no_proto) {
            try no_proto.check(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
        return .proceed;
    }

    pub fn enter_array_expression(
        self: *BasicVisitor,
        expression: ast.ArrayExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_sparse_arrays) {
            try no_sparse_arrays.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        return .proceed;
    }
};
