const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const default_case = @import("default_case.zig");
pub const default_case_last = @import("default_case_last.zig");
pub const eol_last = @import("eol_last.zig");
pub const guard_for_in = @import("guard_for_in.zig");
pub const linebreak_style = @import("linebreak_style.zig");
pub const no_async_promise_executor = @import("no_async_promise_executor.zig");
pub const no_alert = @import("no_alert.zig");
pub const eqeqeq = @import("eqeqeq.zig");
pub const no_array_constructor = @import("no_array_constructor.zig");
pub const no_await_in_loop = @import("no_await_in_loop.zig");
pub const no_buffer_constructor = @import("no_buffer_constructor.zig");
pub const no_caller = @import("no_caller.zig");
pub const no_case_declarations = @import("no_case_declarations.zig");
pub const no_class_assign = @import("no_class_assign.zig");
pub const no_cond_assign = @import("no_cond_assign.zig");
pub const no_compare_neg_zero = @import("no_compare_neg_zero.zig");
pub const no_constant_condition = @import("no_constant_condition.zig");
pub const no_const_assign = @import("no_const_assign.zig");
pub const no_control_regex = @import("no_control_regex.zig");
pub const no_comma_operator = @import("no_comma_operator.zig");
pub const no_console = @import("no_console.zig");
pub const no_continue = @import("no_continue.zig");
pub const no_constructor_return = @import("no_constructor_return.zig");
pub const no_debugger = @import("no_debugger.zig");
pub const no_dupe_else_if = @import("no_dupe_else_if.zig");
pub const no_duplicate_case = @import("no_duplicate_case.zig");
pub const no_dupe_args = @import("no_dupe_args.zig");
pub const no_dupe_class_members = @import("no_dupe_class_members.zig");
pub const no_dupe_keys = @import("no_dupe_keys.zig");
pub const no_delete_var = @import("no_delete_var.zig");
pub const no_div_regex = @import("no_div_regex.zig");
pub const no_empty = @import("no_empty.zig");
pub const no_empty_block_statements = @import("no_empty_block_statements.zig");
pub const no_empty_character_class = @import("no_empty_character_class.zig");
pub const no_empty_function = @import("no_empty_function.zig");
pub const no_empty_pattern = @import("no_empty_pattern.zig");
pub const no_empty_static_block = @import("no_empty_static_block.zig");
pub const no_else_return = @import("no_else_return.zig");
pub const no_eq_null = @import("no_eq_null.zig");
pub const no_eval = @import("no_eval.zig");
pub const no_ex_assign = @import("no_ex_assign.zig");
pub const no_extend_native = @import("no_extend_native.zig");
pub const no_extra_bind = @import("no_extra_bind.zig");
pub const no_extra_label = @import("no_extra_label.zig");
pub const no_extra_boolean_cast = @import("no_extra_boolean_cast.zig");
pub const no_extra_semi = @import("no_extra_semi.zig");
pub const no_floating_decimal = @import("no_floating_decimal.zig");
pub const no_for_in = @import("no_for_in.zig");
pub const no_func_assign = @import("no_func_assign.zig");
pub const no_global_assign = @import("no_global_assign.zig");
pub const no_global_is_finite = @import("no_global_is_finite.zig");
pub const no_global_is_nan = @import("no_global_is_nan.zig");
pub const no_implicit_coercion = @import("no_implicit_coercion.zig");
pub const no_implied_eval = @import("no_implied_eval.zig");
pub const no_import_assign = @import("no_import_assign.zig");
pub const no_inline_comments = @import("no_inline_comments.zig");
pub const no_irregular_whitespace = @import("no_irregular_whitespace.zig");
pub const no_iterator = @import("no_iterator.zig");
pub const no_label_var = @import("no_label_var.zig");
pub const no_labels = @import("no_labels.zig");
pub const no_lone_blocks = @import("no_lone_blocks.zig");
pub const no_lonely_if = @import("no_lonely_if.zig");
pub const no_loss_of_precision = @import("no_loss_of_precision.zig");
pub const no_mixed_spaces_and_tabs = @import("no_mixed_spaces_and_tabs.zig");
pub const no_multi_spaces = @import("no_multi_spaces.zig");
pub const no_multi_str = @import("no_multi_str.zig");
pub const no_multiple_empty_lines = @import("no_multiple_empty_lines.zig");
pub const no_new = @import("no_new.zig");
pub const no_nested_ternary = @import("no_nested_ternary.zig");
pub const no_negated_condition = @import("no_negated_condition.zig");
pub const no_new_native_nonconstructor = @import("no_new_native_nonconstructor.zig");
pub const no_new_func = @import("no_new_func.zig");
pub const no_new_require = @import("no_new_require.zig");
pub const no_obj_calls = @import("no_obj_calls.zig");
pub const no_new_object = @import("no_new_object.zig");
pub const no_new_symbol = @import("no_new_symbol.zig");
pub const no_new_wrappers = @import("no_new_wrappers.zig");
pub const no_octal = @import("no_octal.zig");
pub const no_octal_escape = @import("no_octal_escape.zig");
pub const no_object_constructor = @import("no_object_constructor.zig");
pub const no_path_concat = @import("no_path_concat.zig");
pub const no_plusplus = @import("no_plusplus.zig");
pub const no_promise_executor_return = @import("no_promise_executor_return.zig");
pub const no_proto = @import("no_proto.zig");
pub const no_process_env = @import("no_process_env.zig");
pub const no_process_exit = @import("no_process_exit.zig");
pub const no_prototype_builtins = @import("no_prototype_builtins.zig");
pub const no_regex_spaces = @import("no_regex_spaces.zig");
pub const no_return_await = @import("no_return_await.zig");
pub const no_return_assign = @import("no_return_assign.zig");
pub const no_useless_return = @import("no_useless_return.zig");
pub const no_script_url = @import("no_script_url.zig");
pub const no_self_assign = @import("no_self_assign.zig");
pub const no_self_compare = @import("no_self_compare.zig");
pub const no_setter_return = @import("no_setter_return.zig");
pub const no_shadow_restricted_names = @import("no_shadow_restricted_names.zig");
pub const no_sequences = @import("no_sequences.zig");
pub const no_sparse_arrays = @import("no_sparse_arrays.zig");
pub const no_tabs = @import("no_tabs.zig");
pub const no_ternary = @import("no_ternary.zig");
pub const no_template_curly_in_string = @import("no_template_curly_in_string.zig");
pub const no_throw_literal = @import("no_throw_literal.zig");
pub const no_trailing_spaces = @import("no_trailing_spaces.zig");
pub const no_unreachable = @import("no_unreachable.zig");
pub const no_undef_init = @import("no_undef_init.zig");
pub const no_unneeded_ternary = @import("no_unneeded_ternary.zig");
pub const no_unsafe_finally = @import("no_unsafe_finally.zig");
pub const no_unsafe_negation = @import("no_unsafe_negation.zig");
pub const no_useless_computed_key = @import("no_useless_computed_key.zig");
pub const no_useless_call = @import("no_useless_call.zig");
pub const no_useless_concat = @import("no_useless_concat.zig");
pub const no_useless_constructor = @import("no_useless_constructor.zig");
pub const no_undef = @import("no_undef.zig");
pub const no_useless_catch = @import("no_useless_catch.zig");
pub const no_useless_rename = @import("no_useless_rename.zig");
pub const no_unused_labels = @import("no_unused_labels.zig");
pub const no_unused_vars = @import("no_unused_vars.zig");
pub const no_warning_comments = @import("no_warning_comments.zig");
pub const no_var = @import("no_var.zig");
pub const no_void = @import("no_void.zig");
pub const no_with = @import("no_with.zig");
pub const radix = @import("radix.zig");
pub const unicode_bom = @import("unicode_bom.zig");
pub const use_isnan = @import("use_isnan.zig");
pub const yoda = @import("yoda.zig");

pub fn runBasic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    options: core.Options,
) Allocator.Error!void {
    if (options.no_warning_comments) {
        try no_warning_comments.run(allocator, diagnostics, tree);
    }
    if (options.no_trailing_spaces) {
        try no_trailing_spaces.run(allocator, diagnostics, tree);
    }
    if (options.eol_last) {
        try eol_last.run(allocator, diagnostics, tree);
    }
    if (options.unicode_bom) {
        try unicode_bom.run(allocator, diagnostics, tree);
    }
    if (options.no_tabs) {
        try no_tabs.run(allocator, diagnostics, tree);
    }
    if (options.no_mixed_spaces_and_tabs) {
        try no_mixed_spaces_and_tabs.run(allocator, diagnostics, tree);
    }
    if (options.linebreak_style) {
        try linebreak_style.run(allocator, diagnostics, tree);
    }
    if (options.no_irregular_whitespace) {
        try no_irregular_whitespace.run(allocator, diagnostics, tree);
    }
    if (options.no_multiple_empty_lines) {
        try no_multiple_empty_lines.run(allocator, diagnostics, tree);
    }
    if (options.no_inline_comments) {
        try no_inline_comments.run(allocator, diagnostics, tree);
    }
    if (options.no_multi_spaces) {
        try no_multi_spaces.run(allocator, diagnostics, tree);
    }

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
    if (options.no_async_promise_executor) {
        try no_async_promise_executor.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_array_constructor) {
        try no_array_constructor.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_buffer_constructor) {
        try no_buffer_constructor.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_extra_boolean_cast) {
        try no_extra_boolean_cast.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_eval) {
        try no_eval.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_ex_assign) {
        try no_ex_assign.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_extend_native) {
        try no_extend_native.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_alert) {
        try no_alert.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_class_assign) {
        try no_class_assign.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_const_assign) {
        try no_const_assign.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_func_assign) {
        try no_func_assign.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_global_assign) {
        try no_global_assign.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_global_is_finite) {
        try no_global_is_finite.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_global_is_nan) {
        try no_global_is_nan.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_implied_eval) {
        try no_implied_eval.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_label_var) {
        try no_label_var.run(allocator, diagnostics, tree, semantic_result);
    }

    if (options.no_import_assign) {
        try no_import_assign.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_func) {
        try no_new_func.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_native_nonconstructor) {
        try no_new_native_nonconstructor.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_obj_calls) {
        try no_obj_calls.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_object) {
        try no_new_object.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_object_constructor) {
        try no_object_constructor.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_symbol) {
        try no_new_symbol.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_wrappers) {
        try no_new_wrappers.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_promise_executor_return) {
        try no_promise_executor_return.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.radix) {
        try radix.run(allocator, diagnostics, tree, semantic_result.symbol_table);
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

    pub fn enter_function(
        self: *BasicVisitor,
        function: ast.Function,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_dupe_args) {
            try no_dupe_args.check(self.allocator, self.diagnostics, ctx.tree, function);
        }
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkFunction(self.allocator, self.diagnostics, ctx.tree, function);
        }
        return .proceed;
    }

    pub fn enter_class(
        self: *BasicVisitor,
        class: ast.Class,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkBinding(self.allocator, self.diagnostics, ctx.tree, class.id, false);
        }
        if (self.options.no_useless_constructor) {
            try no_useless_constructor.checkClass(self.allocator, self.diagnostics, ctx.tree, class);
        }
        return .proceed;
    }

    pub fn enter_if_statement(
        self: *BasicVisitor,
        statement: ast.IfStatement,
        index: ast.NodeIndex,
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
        if (self.options.no_dupe_else_if) {
            try no_dupe_else_if.check(self.allocator, self.diagnostics, ctx.tree, statement, index, ctx);
        }
        if (self.options.no_lonely_if) {
            try no_lonely_if.check(self.allocator, self.diagnostics, ctx.tree, statement);
        }
        if (self.options.no_negated_condition) {
            try no_negated_condition.checkIfStatement(self.allocator, self.diagnostics, ctx.tree, statement, index);
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
        if (self.options.no_negated_condition) {
            try no_negated_condition.checkConditionalExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
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

    pub fn enter_empty_statement(
        self: *BasicVisitor,
        _: ast.EmptyStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_extra_semi) {
            try no_extra_semi.check(self.allocator, self.diagnostics, ctx.tree, index, ctx);
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
        if (self.options.no_unreachable) {
            try no_unreachable.checkRange(self.allocator, self.diagnostics, ctx.tree, switch_case.consequent);
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
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkBinding(self.allocator, self.diagnostics, ctx.tree, clause.param, false);
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
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_constructor_return) {
            try no_constructor_return.check(self.allocator, self.diagnostics, ctx.tree, statement, index, ctx);
        }
        if (self.options.no_setter_return) {
            try no_setter_return.check(self.allocator, self.diagnostics, ctx.tree, statement, index, ctx);
        }
        if (self.options.no_return_await) {
            try no_return_await.check(self.allocator, self.diagnostics, ctx.tree, statement, index, ctx);
        }
        if (self.options.no_useless_return) {
            try no_useless_return.check(self.allocator, self.diagnostics, ctx.tree, statement, index, ctx);
        }
        if (self.options.no_return_assign) {
            try no_return_assign.check(self.allocator, self.diagnostics, ctx.tree, statement.argument);
        }
        return .proceed;
    }

    pub fn enter_continue_statement(
        self: *BasicVisitor,
        _: ast.ContinueStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_continue) {
            try no_continue.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_labeled_statement(
        self: *BasicVisitor,
        statement: ast.LabeledStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_extra_label) {
            try no_extra_label.check(self.allocator, self.diagnostics, ctx.tree, statement, index);
        }
        if (self.options.no_unused_labels) {
            try no_unused_labels.check(self.allocator, self.diagnostics, ctx.tree, statement, index);
        }
        if (self.options.no_labels) {
            try no_labels.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_for_in_statement(
        self: *BasicVisitor,
        statement: ast.ForInStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.guard_for_in) {
            try guard_for_in.check(self.allocator, self.diagnostics, ctx.tree, statement, index);
        }
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
        if (self.options.no_empty) {
            try no_empty.checkBlockStatement(self.allocator, self.diagnostics, ctx.tree, block, index);
        }
        if (self.options.no_empty_block_statements) {
            try no_empty_block_statements.checkBlockStatement(self.allocator, self.diagnostics, ctx.tree, block, index);
        }
        if (self.options.no_unreachable) {
            try no_unreachable.checkRange(self.allocator, self.diagnostics, ctx.tree, block.body);
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
        if (self.options.no_empty_function) {
            try no_empty_function.check(self.allocator, self.diagnostics, ctx.tree, body, index);
        }
        if (self.options.no_unreachable) {
            try no_unreachable.checkRange(self.allocator, self.diagnostics, ctx.tree, body.body);
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
        if (self.options.no_empty_static_block) {
            try no_empty_static_block.check(self.allocator, self.diagnostics, ctx.tree, block, index);
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
        if (self.options.no_undef_init) {
            try no_undef_init.check(self.allocator, self.diagnostics, ctx.tree, declaration);
        }
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkVariableDeclaration(self.allocator, self.diagnostics, ctx.tree, declaration);
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
        if (self.options.no_template_curly_in_string) {
            try no_template_curly_in_string.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
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
        if (self.options.no_floating_decimal) {
            try no_floating_decimal.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        if (self.options.no_loss_of_precision) {
            try no_loss_of_precision.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
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
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkFormalParameters(self.allocator, self.diagnostics, ctx.tree, expression.params);
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
        if (self.options.no_implicit_coercion) {
            try no_implicit_coercion.checkAssignmentExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
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
        if (self.options.no_eq_null) {
            try no_eq_null.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
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
        if (self.options.no_implicit_coercion) {
            try no_implicit_coercion.checkBinaryExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_path_concat) {
            try no_path_concat.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.yoda) {
            try yoda.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
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
        if (self.options.no_implicit_coercion) {
            try no_implicit_coercion.checkUnaryExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
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
        if (self.options.no_sequences) {
            try no_sequences.check(self.allocator, self.diagnostics, ctx.tree, expression, index, ctx);
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
        if (self.options.no_prototype_builtins) {
            try no_prototype_builtins.check(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        if (self.options.no_useless_call) {
            try no_useless_call.check(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        if (self.options.no_process_exit) {
            try no_process_exit.check(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        if (self.options.no_extra_bind) {
            try no_extra_bind.check(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        return .proceed;
    }

    pub fn enter_new_expression(
        self: *BasicVisitor,
        expression: ast.NewExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_new) {
            if (ctx.path.parent()) |parent| {
                try no_new.check(self.allocator, self.diagnostics, ctx.tree, index, parent);
            }
        }
        if (self.options.no_new_require) {
            try no_new_require.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        return .proceed;
    }

    pub fn enter_await_expression(
        self: *BasicVisitor,
        _: ast.AwaitExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_await_in_loop) {
            try no_await_in_loop.check(self.allocator, self.diagnostics, ctx.tree, index, ctx);
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
        if (self.options.no_iterator) {
            try no_iterator.check(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
        if (self.options.no_process_env) {
            try no_process_env.check(self.allocator, self.diagnostics, ctx.tree, member, index);
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
        if (self.options.no_useless_computed_key) {
            try no_useless_computed_key.checkObjectExpression(self.allocator, self.diagnostics, ctx.tree, expression);
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
        if (self.options.no_useless_rename) {
            try no_useless_rename.checkObjectPattern(self.allocator, self.diagnostics, ctx.tree, pattern);
        }
        if (self.options.no_useless_computed_key) {
            try no_useless_computed_key.checkObjectPattern(self.allocator, self.diagnostics, ctx.tree, pattern);
        }
        return .proceed;
    }

    pub fn enter_class_body(
        self: *BasicVisitor,
        body: ast.ClassBody,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_dupe_class_members) {
            try no_dupe_class_members.check(self.allocator, self.diagnostics, ctx.tree, body);
        }
        return .proceed;
    }

    pub fn enter_method_definition(
        self: *BasicVisitor,
        method: ast.MethodDefinition,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_useless_computed_key) {
            try no_useless_computed_key.checkMethodDefinition(self.allocator, self.diagnostics, ctx.tree, method, index);
        }
        return .proceed;
    }

    pub fn enter_property_definition(
        self: *BasicVisitor,
        property: ast.PropertyDefinition,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_useless_computed_key) {
            try no_useless_computed_key.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property, index);
        }
        return .proceed;
    }

    pub fn enter_import_specifier(
        self: *BasicVisitor,
        specifier: ast.ImportSpecifier,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_useless_rename) {
            try no_useless_rename.checkImportSpecifier(self.allocator, self.diagnostics, ctx.tree, specifier, index);
        }
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkBinding(self.allocator, self.diagnostics, ctx.tree, specifier.local, false);
        }
        return .proceed;
    }

    pub fn enter_import_default_specifier(
        self: *BasicVisitor,
        specifier: ast.ImportDefaultSpecifier,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkBinding(self.allocator, self.diagnostics, ctx.tree, specifier.local, false);
        }
        return .proceed;
    }

    pub fn enter_import_namespace_specifier(
        self: *BasicVisitor,
        specifier: ast.ImportNamespaceSpecifier,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkBinding(self.allocator, self.diagnostics, ctx.tree, specifier.local, false);
        }
        return .proceed;
    }

    pub fn enter_export_specifier(
        self: *BasicVisitor,
        specifier: ast.ExportSpecifier,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_useless_rename) {
            try no_useless_rename.checkExportSpecifier(self.allocator, self.diagnostics, ctx.tree, specifier, index);
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
        if (self.options.no_div_regex) {
            try no_div_regex.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        if (self.options.no_regex_spaces) {
            try no_regex_spaces.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        return .proceed;
    }
};
