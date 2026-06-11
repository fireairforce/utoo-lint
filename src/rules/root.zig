const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const default_case = @import("default_case.zig");
pub const default_case_last = @import("default_case_last.zig");
pub const no_alert = @import("no_alert.zig");
pub const eqeqeq = @import("eqeqeq.zig");
pub const no_array_constructor = @import("no_array_constructor.zig");
pub const no_caller = @import("no_caller.zig");
pub const no_case_declarations = @import("no_case_declarations.zig");
pub const no_cond_assign = @import("no_cond_assign.zig");
pub const no_compare_neg_zero = @import("no_compare_neg_zero.zig");
pub const no_constant_condition = @import("no_constant_condition.zig");
pub const no_control_regex = @import("no_control_regex.zig");
pub const no_comma_operator = @import("no_comma_operator.zig");
pub const no_console = @import("no_console.zig");
pub const no_debugger = @import("no_debugger.zig");
pub const no_duplicate_case = @import("no_duplicate_case.zig");
pub const no_dupe_keys = @import("no_dupe_keys.zig");
pub const no_delete_var = @import("no_delete_var.zig");
pub const no_empty_block_statements = @import("no_empty_block_statements.zig");
pub const no_empty_character_class = @import("no_empty_character_class.zig");
pub const no_empty_pattern = @import("no_empty_pattern.zig");
pub const no_else_return = @import("no_else_return.zig");
pub const no_extra_boolean_cast = @import("no_extra_boolean_cast.zig");
pub const no_for_in = @import("no_for_in.zig");
pub const no_global_is_finite = @import("no_global_is_finite.zig");
pub const no_global_is_nan = @import("no_global_is_nan.zig");
pub const no_labels = @import("no_labels.zig");
pub const no_lone_blocks = @import("no_lone_blocks.zig");
pub const no_lonely_if = @import("no_lonely_if.zig");
pub const no_multi_str = @import("no_multi_str.zig");
pub const no_new = @import("no_new.zig");
pub const no_nested_ternary = @import("no_nested_ternary.zig");
pub const no_new_func = @import("no_new_func.zig");
pub const no_new_object = @import("no_new_object.zig");
pub const no_new_symbol = @import("no_new_symbol.zig");
pub const no_new_wrappers = @import("no_new_wrappers.zig");
pub const no_octal = @import("no_octal.zig");
pub const no_octal_escape = @import("no_octal_escape.zig");
pub const no_plusplus = @import("no_plusplus.zig");
pub const no_proto = @import("no_proto.zig");
pub const no_regex_spaces = @import("no_regex_spaces.zig");
pub const no_return_assign = @import("no_return_assign.zig");
pub const no_script_url = @import("no_script_url.zig");
pub const no_self_assign = @import("no_self_assign.zig");
pub const no_self_compare = @import("no_self_compare.zig");
pub const no_sparse_arrays = @import("no_sparse_arrays.zig");
pub const no_ternary = @import("no_ternary.zig");
pub const no_throw_literal = @import("no_throw_literal.zig");
pub const no_unneeded_ternary = @import("no_unneeded_ternary.zig");
pub const no_unsafe_finally = @import("no_unsafe_finally.zig");
pub const no_unsafe_negation = @import("no_unsafe_negation.zig");
pub const no_useless_concat = @import("no_useless_concat.zig");
pub const no_undef = @import("no_undef.zig");
pub const no_useless_catch = @import("no_useless_catch.zig");
pub const no_unused_vars = @import("no_unused_vars.zig");
pub const no_var = @import("no_var.zig");
pub const no_void = @import("no_void.zig");
pub const no_with = @import("no_with.zig");
pub const use_isnan = @import("use_isnan.zig");

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

    if (options.no_extra_boolean_cast) {
        try no_extra_boolean_cast.run(allocator, diagnostics, tree, semantic_result.symbol_table);
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

    pub fn enter_if_statement(
        self: *BasicVisitor,
        statement: ast.IfStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_cond_assign) {
            try no_cond_assign.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        if (self.options.no_constant_condition) {
            try no_constant_condition.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        if (self.options.no_else_return) {
            try no_else_return.check(self.allocator, self.diagnostics, ctx.tree, statement);
        }
        if (self.options.no_lonely_if) {
            try no_lonely_if.check(self.allocator, self.diagnostics, ctx.tree, statement);
        }
        return .proceed;
    }

    pub fn enter_while_statement(
        self: *BasicVisitor,
        statement: ast.WhileStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_cond_assign) {
            try no_cond_assign.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        if (self.options.no_constant_condition) {
            try no_constant_condition.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        return .proceed;
    }

    pub fn enter_do_while_statement(
        self: *BasicVisitor,
        statement: ast.DoWhileStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_cond_assign) {
            try no_cond_assign.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        if (self.options.no_constant_condition) {
            try no_constant_condition.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        return .proceed;
    }

    pub fn enter_for_statement(
        self: *BasicVisitor,
        statement: ast.ForStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_cond_assign and statement.@"test" != .null) {
            try no_cond_assign.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        if (self.options.no_constant_condition and statement.@"test" != .null) {
            try no_constant_condition.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        return .proceed;
    }

    pub fn enter_conditional_expression(
        self: *BasicVisitor,
        expression: ast.ConditionalExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_constant_condition) {
            try no_constant_condition.check(self.allocator, self.diagnostics, ctx.tree, expression.@"test");
        }
        if (self.options.no_nested_ternary) {
            try no_nested_ternary.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_unneeded_ternary) {
            try no_unneeded_ternary.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_ternary) {
            try no_ternary.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        return .proceed;
    }

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

    pub fn enter_switch_statement(
        self: *BasicVisitor,
        statement: ast.SwitchStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.default_case) {
            try default_case.check(self.allocator, self.diagnostics, ctx.tree, statement, index);
        }
        if (self.options.default_case_last) {
            try default_case_last.check(self.allocator, self.diagnostics, ctx.tree, statement);
        }
        if (self.options.no_duplicate_case) {
            try no_duplicate_case.check(self.allocator, self.diagnostics, ctx.tree, statement);
        }
        return .proceed;
    }

    pub fn enter_switch_case(
        self: *BasicVisitor,
        switch_case: ast.SwitchCase,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_case_declarations) {
            try no_case_declarations.check(self.allocator, self.diagnostics, ctx.tree, switch_case);
        }
        return .proceed;
    }

    pub fn enter_try_statement(
        self: *BasicVisitor,
        statement: ast.TryStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_unsafe_finally) {
            try no_unsafe_finally.check(self.allocator, self.diagnostics, ctx.tree, statement);
        }
        return .proceed;
    }

    pub fn enter_catch_clause(
        self: *BasicVisitor,
        clause: ast.CatchClause,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_useless_catch) {
            try no_useless_catch.check(self.allocator, self.diagnostics, ctx.tree, clause, index);
        }
        return .proceed;
    }

    pub fn enter_throw_statement(
        self: *BasicVisitor,
        statement: ast.ThrowStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_throw_literal) {
            try no_throw_literal.check(self.allocator, self.diagnostics, ctx.tree, statement, index);
        }
        return .proceed;
    }

    pub fn enter_return_statement(
        self: *BasicVisitor,
        statement: ast.ReturnStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_return_assign) {
            try no_return_assign.check(self.allocator, self.diagnostics, ctx.tree, statement.argument);
        }
        return .proceed;
    }

    pub fn enter_labeled_statement(
        self: *BasicVisitor,
        _: ast.LabeledStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_labels) {
            try no_labels.check(self.allocator, self.diagnostics, ctx.tree, index);
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
        if (self.options.no_lone_blocks) {
            if (ctx.path.parent()) |parent| {
                try no_lone_blocks.check(self.allocator, self.diagnostics, ctx.tree, block, index, parent);
            }
        }
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

    pub fn enter_string_literal(
        self: *BasicVisitor,
        literal: ast.StringLiteral,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_script_url) {
            try no_script_url.checkStringLiteral(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        if (self.options.no_multi_str) {
            try no_multi_str.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        if (self.options.no_octal_escape) {
            try no_octal_escape.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_template_literal(
        self: *BasicVisitor,
        literal: ast.TemplateLiteral,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_script_url) {
            try no_script_url.checkTemplateLiteral(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        return .proceed;
    }

    pub fn enter_numeric_literal(
        self: *BasicVisitor,
        literal: ast.NumericLiteral,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_octal) {
            try no_octal.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        return .proceed;
    }

    pub fn enter_arrow_function_expression(
        self: *BasicVisitor,
        expression: ast.ArrowFunctionExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_return_assign and expression.expression) {
            try no_return_assign.check(self.allocator, self.diagnostics, ctx.tree, expression.body);
        }
        return .proceed;
    }

    pub fn enter_assignment_expression(
        self: *BasicVisitor,
        expression: ast.AssignmentExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_self_assign) {
            try no_self_assign.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
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
        if (self.options.use_isnan) {
            try use_isnan.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_useless_concat) {
            try no_useless_concat.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
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

    pub fn enter_update_expression(
        self: *BasicVisitor,
        _: ast.UpdateExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_plusplus) {
            try no_plusplus.check(self.allocator, self.diagnostics, ctx.tree, index);
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

    pub fn enter_new_expression(
        self: *BasicVisitor,
        _: ast.NewExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_new) {
            if (ctx.path.parent()) |parent| {
                try no_new.check(self.allocator, self.diagnostics, ctx.tree, index, parent);
            }
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

    pub fn enter_object_expression(
        self: *BasicVisitor,
        expression: ast.ObjectExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_dupe_keys) {
            try no_dupe_keys.check(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        return .proceed;
    }

    pub fn enter_object_pattern(
        self: *BasicVisitor,
        pattern: ast.ObjectPattern,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_empty_pattern) {
            try no_empty_pattern.checkObjectPattern(self.allocator, self.diagnostics, ctx.tree, pattern, index);
        }
        return .proceed;
    }

    pub fn enter_array_pattern(
        self: *BasicVisitor,
        pattern: ast.ArrayPattern,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_empty_pattern) {
            try no_empty_pattern.checkArrayPattern(self.allocator, self.diagnostics, ctx.tree, pattern, index);
        }
        return .proceed;
    }

    pub fn enter_regexp_literal(
        self: *BasicVisitor,
        literal: ast.RegExpLiteral,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_control_regex) {
            try no_control_regex.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        if (self.options.no_empty_character_class) {
            try no_empty_character_class.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        if (self.options.no_regex_spaces) {
            try no_regex_spaces.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        return .proceed;
    }
};
