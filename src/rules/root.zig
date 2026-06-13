const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

const global_call_checks = @import("global_call_checks.zig");
const global_is_checks = @import("global_is_checks.zig");
const native_object_checks = @import("native_object_checks.zig");
const object_constructor_checks = @import("object_constructor_checks.zig");
const promise_checks = @import("promise_checks.zig");
const symbol_checks = @import("symbol_checks.zig");

pub const curly = @import("curly.zig");
pub const array_callback_return = @import("array_callback_return.zig");
pub const block_scoped_var = @import("block_scoped_var.zig");
pub const constructor_super = @import("constructor_super.zig");
pub const dot_notation = @import("dot_notation.zig");
pub const default_case = @import("default_case.zig");
pub const default_case_last = @import("default_case_last.zig");
pub const eol_last = @import("eol_last.zig");
pub const for_direction = @import("for_direction.zig");
pub const getter_return = @import("getter_return.zig");
pub const guard_for_in = @import("guard_for_in.zig");
pub const alipay_ant_no_import_src = @import("alipay_ant_no_import_src.zig");
pub const import_first = @import("import_first.zig");
pub const import_newline_after_import = @import("import_newline_after_import.zig");
pub const import_no_amd = @import("import_no_amd.zig");
pub const import_no_duplicates = @import("import_no_duplicates.zig");
pub const import_no_self_import = @import("import_no_self_import.zig");
pub const jsx_a11y_alt_text = @import("jsx_a11y_alt_text.zig");
pub const jsx_a11y_anchor_has_content = @import("jsx_a11y_anchor_has_content.zig");
pub const jsx_a11y_aria_props = @import("jsx_a11y_aria_props.zig");
pub const jsx_a11y_aria_proptypes = @import("jsx_a11y_aria_proptypes.zig");
pub const jsx_a11y_aria_role = @import("jsx_a11y_aria_role.zig");
pub const jsx_a11y_aria_unsupported_elements = @import("jsx_a11y_aria_unsupported_elements.zig");
pub const jsx_a11y_iframe_has_title = @import("jsx_a11y_iframe_has_title.zig");
pub const jsx_a11y_img_redundant_alt = @import("jsx_a11y_img_redundant_alt.zig");
pub const jsx_a11y_no_access_key = @import("jsx_a11y_no_access_key.zig");
pub const jsx_a11y_no_distracting_elements = @import("jsx_a11y_no_distracting_elements.zig");
pub const jsx_a11y_role_has_required_aria_props = @import("jsx_a11y_role_has_required_aria_props.zig");
pub const jsx_a11y_role_supports_aria_props = @import("jsx_a11y_role_supports_aria_props.zig");
pub const jsx_a11y_scope = @import("jsx_a11y_scope.zig");
pub const linebreak_style = @import("linebreak_style.zig");
pub const new_cap = @import("new_cap.zig");
pub const new_parens = @import("new_parens.zig");
pub const no_async_promise_executor = @import("no_async_promise_executor.zig");
pub const no_alert = @import("no_alert.zig");
pub const eqeqeq = @import("eqeqeq.zig");
pub const no_array_constructor = @import("no_array_constructor.zig");
pub const no_await_in_loop = @import("no_await_in_loop.zig");
pub const no_bitwise = @import("no_bitwise.zig");
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
pub const no_duplicate_imports = @import("no_duplicate_imports.zig");
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
pub const no_fallthrough = @import("no_fallthrough.zig");
pub const no_for_in = @import("no_for_in.zig");
pub const no_func_assign = @import("no_func_assign.zig");
pub const no_global_assign = @import("no_global_assign.zig");
pub const no_global_is_finite = @import("no_global_is_finite.zig");
pub const no_global_is_nan = @import("no_global_is_nan.zig");
pub const no_implicit_coercion = @import("no_implicit_coercion.zig");
pub const no_implied_eval = @import("no_implied_eval.zig");
pub const no_import_assign = @import("no_import_assign.zig");
pub const no_inline_comments = @import("no_inline_comments.zig");
pub const no_inner_declarations = @import("no_inner_declarations.zig");
pub const no_invalid_regexp = @import("no_invalid_regexp.zig");
pub const no_irregular_whitespace = @import("no_irregular_whitespace.zig");
pub const no_iterator = @import("no_iterator.zig");
pub const no_label_var = @import("no_label_var.zig");
pub const no_labels = @import("no_labels.zig");
pub const no_lone_blocks = @import("no_lone_blocks.zig");
pub const no_lonely_if = @import("no_lonely_if.zig");
pub const no_loop_func = @import("no_loop_func.zig");
pub const no_loss_of_precision = @import("no_loss_of_precision.zig");
pub const no_mixed_spaces_and_tabs = @import("no_mixed_spaces_and_tabs.zig");
pub const no_misleading_character_class = @import("no_misleading_character_class.zig");
pub const no_multi_assign = @import("no_multi_assign.zig");
pub const no_multi_spaces = @import("no_multi_spaces.zig");
pub const no_multi_str = @import("no_multi_str.zig");
pub const no_multiple_empty_lines = @import("no_multiple_empty_lines.zig");
pub const no_nonoctal_decimal_escape = @import("no_nonoctal_decimal_escape.zig");
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
pub const no_param_reassign = @import("no_param_reassign.zig");
pub const no_path_concat = @import("no_path_concat.zig");
pub const no_plusplus = @import("no_plusplus.zig");
pub const no_promise_executor_return = @import("no_promise_executor_return.zig");
pub const no_proto = @import("no_proto.zig");
pub const no_process_env = @import("no_process_env.zig");
pub const no_process_exit = @import("no_process_exit.zig");
pub const no_prototype_builtins = @import("no_prototype_builtins.zig");
pub const no_redeclare = @import("no_redeclare.zig");
pub const no_regex_spaces = @import("no_regex_spaces.zig");
pub const no_return_await = @import("no_return_await.zig");
pub const no_return_assign = @import("no_return_assign.zig");
pub const no_useless_return = @import("no_useless_return.zig");
pub const no_script_url = @import("no_script_url.zig");
pub const no_self_assign = @import("no_self_assign.zig");
pub const no_self_compare = @import("no_self_compare.zig");
pub const no_setter_return = @import("no_setter_return.zig");
pub const no_shadow = @import("no_shadow.zig");
pub const no_shadow_restricted_names = @import("no_shadow_restricted_names.zig");
pub const no_sequences = @import("no_sequences.zig");
pub const no_sparse_arrays = @import("no_sparse_arrays.zig");
pub const no_tabs = @import("no_tabs.zig");
pub const no_ternary = @import("no_ternary.zig");
pub const no_template_curly_in_string = @import("no_template_curly_in_string.zig");
pub const no_throw_literal = @import("no_throw_literal.zig");
pub const no_this_before_super = @import("no_this_before_super.zig");
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
pub const no_useless_escape = @import("no_useless_escape.zig");
pub const no_useless_rename = @import("no_useless_rename.zig");
pub const no_unused_expressions = @import("no_unused_expressions.zig");
pub const no_unused_labels = @import("no_unused_labels.zig");
pub const no_unused_vars = @import("no_unused_vars.zig");
pub const no_use_before_define = @import("no_use_before_define.zig");
pub const no_warning_comments = @import("no_warning_comments.zig");
pub const no_var = @import("no_var.zig");
pub const no_void = @import("no_void.zig");
pub const no_with = @import("no_with.zig");
pub const object_shorthand = @import("object_shorthand.zig");
pub const one_var = @import("one_var.zig");
pub const operator_assignment = @import("operator_assignment.zig");
pub const prefer_const = @import("prefer_const.zig");
pub const prefer_destructuring = @import("prefer_destructuring.zig");
pub const prefer_exponentiation_operator = @import("prefer_exponentiation_operator.zig");
pub const prefer_promise_reject_errors = @import("prefer_promise_reject_errors.zig");
pub const prefer_regex_literals = @import("prefer_regex_literals.zig");
pub const prefer_rest_params = @import("prefer_rest_params.zig");
pub const prefer_spread = @import("prefer_spread.zig");
pub const prefer_template = @import("prefer_template.zig");
pub const react_button_has_type = @import("react_button_has_type.zig");
pub const react_jsx_boolean_value = @import("react_jsx_boolean_value.zig");
pub const react_jsx_no_duplicate_props = @import("react_jsx_no_duplicate_props.zig");
pub const react_jsx_no_comment_textnodes = @import("react_jsx_no_comment_textnodes.zig");
pub const react_jsx_no_bind = @import("react_jsx_no_bind.zig");
pub const react_jsx_key = @import("react_jsx_key.zig");
pub const react_jsx_no_target_blank = @import("react_jsx_no_target_blank.zig");
pub const react_jsx_no_undef = @import("react_jsx_no_undef.zig");
pub const react_jsx_pascal_case = @import("react_jsx_pascal_case.zig");
pub const react_jsx_uses_react = @import("react_jsx_uses_react.zig");
pub const react_jsx_uses_vars = @import("react_jsx_uses_vars.zig");
pub const react_no_danger = @import("react_no_danger.zig");
pub const react_no_danger_with_children = @import("react_no_danger_with_children.zig");
pub const react_no_children_prop = @import("react_no_children_prop.zig");
pub const react_no_array_index_key = @import("react_no_array_index_key.zig");
pub const react_no_find_dom_node = @import("react_no_find_dom_node.zig");
pub const react_no_is_mounted = @import("react_no_is_mounted.zig");
pub const react_no_multi_comp = @import("react_no_multi_comp.zig");
pub const react_no_redundant_should_component_update = @import("react_no_redundant_should_component_update.zig");
pub const react_no_render_return_value = @import("react_no_render_return_value.zig");
pub const react_no_this_in_sfc = @import("react_no_this_in_sfc.zig");
pub const react_no_will_update_set_state = @import("react_no_will_update_set_state.zig");
pub const react_require_render_return = @import("react_require_render_return.zig");
pub const react_no_string_refs = @import("react_no_string_refs.zig");
pub const react_no_unescaped_entities = @import("react_no_unescaped_entities.zig");
pub const react_prefer_es6_class = @import("react_prefer_es6_class.zig");
pub const react_style_prop_object = @import("react_style_prop_object.zig");
pub const react_self_closing_comp = @import("react_self_closing_comp.zig");
pub const react_void_dom_elements_no_children = @import("react_void_dom_elements_no_children.zig");
pub const radix = @import("radix.zig");
pub const require_atomic_updates = @import("require_atomic_updates.zig");
const reassignment_rules = @import("reassignment_rules.zig");
pub const require_yield = @import("require_yield.zig");
pub const spaced_comment = @import("spaced_comment.zig");
pub const symbol_description = @import("symbol_description.zig");
pub const typescript_eslint_adjacent_overload_signatures = @import("typescript_eslint_adjacent_overload_signatures.zig");
pub const typescript_eslint_array_type = @import("typescript_eslint_array_type.zig");
pub const typescript_eslint_class_literal_property_style = @import("typescript_eslint_class_literal_property_style.zig");
pub const typescript_eslint_consistent_type_assertions = @import("typescript_eslint_consistent_type_assertions.zig");
pub const typescript_eslint_consistent_type_definitions = @import("typescript_eslint_consistent_type_definitions.zig");
pub const typescript_eslint_dot_notation = @import("typescript_eslint_dot_notation.zig");
pub const typescript_eslint_no_array_constructor = @import("typescript_eslint_no_array_constructor.zig");
pub const typescript_eslint_ban_types = @import("typescript_eslint_ban_types.zig");
pub const typescript_eslint_ban_ts_comment = @import("typescript_eslint_ban_ts_comment.zig");
pub const typescript_eslint_ban_tslint_comment = @import("typescript_eslint_ban_tslint_comment.zig");
pub const typescript_eslint_explicit_member_accessibility = @import("typescript_eslint_explicit_member_accessibility.zig");
pub const typescript_eslint_member_ordering = @import("typescript_eslint_member_ordering.zig");
pub const typescript_eslint_method_signature_style = @import("typescript_eslint_method_signature_style.zig");
pub const typescript_eslint_no_confusing_non_null_assertion = @import("typescript_eslint_no_confusing_non_null_assertion.zig");
pub const typescript_eslint_no_dupe_class_members = @import("typescript_eslint_no_dupe_class_members.zig");
pub const typescript_eslint_no_empty_function = @import("typescript_eslint_no_empty_function.zig");
pub const typescript_eslint_no_empty_interface = @import("typescript_eslint_no_empty_interface.zig");
pub const typescript_eslint_no_extra_semi = @import("typescript_eslint_no_extra_semi.zig");
pub const typescript_eslint_no_extra_non_null_assertion = @import("typescript_eslint_no_extra_non_null_assertion.zig");
pub const typescript_eslint_no_inferrable_types = @import("typescript_eslint_no_inferrable_types.zig");
pub const typescript_eslint_no_invalid_void_type = @import("typescript_eslint_no_invalid_void_type.zig");
pub const typescript_eslint_no_loss_of_precision = @import("typescript_eslint_no_loss_of_precision.zig");
pub const typescript_eslint_no_loop_func = @import("typescript_eslint_no_loop_func.zig");
pub const typescript_eslint_no_misused_new = @import("typescript_eslint_no_misused_new.zig");
pub const typescript_eslint_no_namespace = @import("typescript_eslint_no_namespace.zig");
pub const typescript_eslint_no_non_null_asserted_optional_chain = @import("typescript_eslint_no_non_null_asserted_optional_chain.zig");
pub const typescript_eslint_no_redeclare = @import("typescript_eslint_no_redeclare.zig");
pub const typescript_eslint_no_require_imports = @import("typescript_eslint_no_require_imports.zig");
pub const typescript_eslint_no_shadow = @import("typescript_eslint_no_shadow.zig");
pub const typescript_eslint_no_this_alias = @import("typescript_eslint_no_this_alias.zig");
pub const typescript_eslint_triple_slash_reference = @import("typescript_eslint_triple_slash_reference.zig");
pub const typescript_eslint_typedef = @import("typescript_eslint_typedef.zig");
pub const typescript_eslint_unified_signatures = @import("typescript_eslint_unified_signatures.zig");
pub const typescript_eslint_no_unnecessary_type_constraint = @import("typescript_eslint_no_unnecessary_type_constraint.zig");
pub const typescript_eslint_no_useless_constructor = @import("typescript_eslint_no_useless_constructor.zig");
pub const typescript_eslint_no_unused_expressions = @import("typescript_eslint_no_unused_expressions.zig");
pub const typescript_eslint_no_unused_vars = @import("typescript_eslint_no_unused_vars.zig");
pub const typescript_eslint_no_use_before_define = @import("typescript_eslint_no_use_before_define.zig");
pub const typescript_eslint_no_var_requires = @import("typescript_eslint_no_var_requires.zig");
pub const typescript_eslint_prefer_as_const = @import("typescript_eslint_prefer_as_const.zig");
pub const typescript_eslint_prefer_namespace_keyword = @import("typescript_eslint_prefer_namespace_keyword.zig");
pub const typescript_eslint_restrict_plus_operands = @import("typescript_eslint_restrict_plus_operands.zig");
pub const unicode_bom = @import("unicode_bom.zig");
pub const use_isnan = @import("use_isnan.zig");
pub const valid_typeof = @import("valid_typeof.zig");
pub const yoda = @import("yoda.zig");

pub fn runBasic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
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
    if (options.spaced_comment) {
        try spaced_comment.run(allocator, diagnostics, tree);
    }
    if (options.typescript_eslint_ban_ts_comment) {
        try typescript_eslint_ban_ts_comment.run(allocator, diagnostics, tree);
    }
    if (options.typescript_eslint_ban_tslint_comment) {
        try typescript_eslint_ban_tslint_comment.run(allocator, diagnostics, tree);
    }
    if (options.typescript_eslint_triple_slash_reference) {
        try typescript_eslint_triple_slash_reference.run(allocator, diagnostics, tree);
    }
    if (options.typescript_eslint_no_non_null_asserted_optional_chain) {
        try typescript_eslint_no_non_null_asserted_optional_chain.run(allocator, diagnostics, tree);
    }

    var visitor = BasicVisitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .file_path = file_path,
        .options = options,
    };
    defer visitor.react_no_array_index_key_state.deinit(allocator);
    defer visitor.react_jsx_no_bind_state.deinit(allocator);
    defer visitor.react_require_render_return_state.deinit(allocator);

    try traverser.basic.traverse(BasicVisitor, tree, &visitor);
}

pub fn runSemantic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    semantic_result: traverser.semantic.Result,
    options: core.Options,
) Allocator.Error!void {
    if (options.block_scoped_var) {
        try block_scoped_var.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    const promise_check_options =
        options.no_async_promise_executor or
        options.no_promise_executor_return or
        options.prefer_promise_reject_errors;

    if (options.no_array_constructor and !options.typescript_eslint_no_array_constructor) {
        try no_array_constructor.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_buffer_constructor) {
        try no_buffer_constructor.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_extra_boolean_cast) {
        try no_extra_boolean_cast.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_extend_native) {
        try no_extend_native.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_eval or options.no_alert or options.no_implied_eval) {
        try global_call_checks.run(
            allocator,
            diagnostics,
            tree,
            semantic_result.symbol_table,
            options.no_eval,
            options.no_alert,
            options.no_implied_eval,
        );
    }

    const use_typescript_no_redeclare = options.typescript_eslint_no_redeclare and tree.isTs();

    if (options.no_redeclare and !use_typescript_no_redeclare) {
        try no_redeclare.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (use_typescript_no_redeclare) {
        try typescript_eslint_no_redeclare.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    const use_typescript_no_shadow = options.typescript_eslint_no_shadow and tree.isTs();

    if (options.no_shadow and !use_typescript_no_shadow) {
        try no_shadow.run(allocator, diagnostics, tree, semantic_result.scope_tree, semantic_result.symbol_table);
    }

    if (use_typescript_no_shadow) {
        try typescript_eslint_no_shadow.run(allocator, diagnostics, tree, semantic_result.scope_tree, semantic_result.symbol_table);
    }

    if (reassignment_rules.shouldRun(options)) {
        try reassignment_rules.run(allocator, diagnostics, tree, semantic_result.symbol_table, options);
    }

    if (options.no_global_assign) {
        try no_global_assign.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_global_is_finite or options.no_global_is_nan) {
        try global_is_checks.run(
            allocator,
            diagnostics,
            tree,
            semantic_result.symbol_table,
            options.no_global_is_finite,
            options.no_global_is_nan,
        );
    }

    if (options.no_label_var) {
        try no_label_var.run(allocator, diagnostics, tree, semantic_result);
    }

    if (options.no_invalid_regexp) {
        try no_invalid_regexp.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_misleading_character_class) {
        try no_misleading_character_class.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    const use_typescript_no_loop_func = options.typescript_eslint_no_loop_func and tree.isTs();
    if (options.no_loop_func and !use_typescript_no_loop_func) {
        try no_loop_func.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }
    if (use_typescript_no_loop_func) {
        try typescript_eslint_no_loop_func.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_func) {
        try no_new_func.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_native_nonconstructor or options.no_obj_calls) {
        try native_object_checks.run(
            allocator,
            diagnostics,
            tree,
            semantic_result.symbol_table,
            options.no_new_native_nonconstructor,
            options.no_obj_calls,
        );
    }

    if (options.no_new_object or options.no_object_constructor) {
        try object_constructor_checks.run(
            allocator,
            diagnostics,
            tree,
            semantic_result.symbol_table,
            options.no_new_object,
            options.no_object_constructor,
        );
    }

    if (options.typescript_eslint_no_require_imports) {
        try typescript_eslint_no_require_imports.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.typescript_eslint_no_var_requires) {
        try typescript_eslint_no_var_requires.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_new_symbol or options.symbol_description) {
        try symbol_checks.run(
            allocator,
            diagnostics,
            tree,
            semantic_result.symbol_table,
            options.no_new_symbol,
            options.symbol_description,
        );
    }

    if (options.no_new_wrappers) {
        try no_new_wrappers.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (promise_check_options) {
        try promise_checks.run(
            allocator,
            diagnostics,
            tree,
            semantic_result.symbol_table,
            options.no_async_promise_executor,
            options.no_promise_executor_return,
            options.prefer_promise_reject_errors,
        );
    }

    if (options.prefer_exponentiation_operator) {
        try prefer_exponentiation_operator.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.prefer_regex_literals) {
        try prefer_regex_literals.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.radix) {
        try radix.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.require_atomic_updates) {
        try require_atomic_updates.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_unused_vars and !options.typescript_eslint_no_unused_vars) {
        try no_unused_vars.runWithOptions(allocator, diagnostics, tree, semantic_result.symbol_table, .{
            .react_jsx_uses_react = options.react_jsx_uses_react,
            .react_jsx_uses_vars = options.react_jsx_uses_vars,
        });
    }

    if (options.typescript_eslint_no_unused_vars) {
        try typescript_eslint_no_unused_vars.run(
            allocator,
            diagnostics,
            tree,
            semantic_result.symbol_table,
            options.react_jsx_uses_react,
            options.react_jsx_uses_vars,
        );
    }

    if (options.no_use_before_define and !options.typescript_eslint_no_use_before_define) {
        try no_use_before_define.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.typescript_eslint_no_use_before_define) {
        try typescript_eslint_no_use_before_define.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_undef) {
        try no_undef.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.react_jsx_no_undef) {
        try react_jsx_no_undef.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.prefer_const) {
        try prefer_const.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }
}

const BasicVisitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    file_path: []const u8,
    options: core.Options,
    react_button_has_type_state: react_button_has_type.State = .{},
    react_require_render_return_state: react_require_render_return.State = .{},
    react_no_danger_with_children_bindings: react_no_danger_with_children.ObjectBindings = .{},
    react_no_children_prop_bindings: react_no_children_prop.ReactBindings = .{},
    react_no_array_index_key_state: react_no_array_index_key.State = .{},
    react_jsx_no_bind_state: react_jsx_no_bind.State = .{},
    react_jsx_key_state: react_jsx_key.State = .{},
    react_no_multi_comp_state: react_no_multi_comp.State = .{},
    react_style_prop_object_bindings: react_style_prop_object.Bindings = .{},
    react_void_dom_elements_no_children_bindings: react_void_dom_elements_no_children.ReactBindings = .{},

    pub fn enter_program(
        self: *BasicVisitor,
        program: ast.Program,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.import_first) {
            try import_first.check(self.allocator, self.diagnostics, ctx.tree, program);
        }
        if (self.options.import_newline_after_import) {
            try import_newline_after_import.check(self.allocator, self.diagnostics, ctx.tree, program);
        }
        if (self.options.import_no_duplicates) {
            try import_no_duplicates.check(self.allocator, self.diagnostics, ctx.tree, program);
        }
        if (self.options.alipay_ant_no_import_src) {
            try alipay_ant_no_import_src.check(self.allocator, self.diagnostics, ctx.tree, program);
        }
        if (self.options.import_no_self_import) {
            try import_no_self_import.check(self.allocator, self.diagnostics, ctx.tree, program, self.file_path);
        }
        if (self.options.react_no_children_prop) {
            self.react_no_children_prop_bindings = react_no_children_prop.bindingsFromProgram(ctx.tree, program);
        }
        if (self.options.react_button_has_type) {
            react_button_has_type.collectProgram(ctx.tree, program, &self.react_button_has_type_state);
        }
        if (self.options.react_require_render_return) {
            try react_require_render_return.collectProgram(self.allocator, ctx.tree, program, &self.react_require_render_return_state);
        }
        if (self.options.react_no_array_index_key) {
            try react_no_array_index_key.collectProgram(self.allocator, ctx.tree, program, &self.react_no_array_index_key_state);
        }
        if (self.options.react_jsx_key) {
            react_jsx_key.collectProgram(ctx.tree, &self.react_jsx_key_state);
        }
        if (self.options.react_void_dom_elements_no_children) {
            self.react_void_dom_elements_no_children_bindings = react_void_dom_elements_no_children.bindingsFromProgram(ctx.tree, program);
        }
        if (self.options.react_style_prop_object) {
            self.react_style_prop_object_bindings = react_style_prop_object.bindingsFromProgram(ctx.tree, program);
        }
        if (self.options.no_duplicate_imports and !self.options.import_no_duplicates) {
            try no_duplicate_imports.check(self.allocator, self.diagnostics, ctx.tree, program);
        }
        if (self.options.typescript_eslint_adjacent_overload_signatures) {
            try typescript_eslint_adjacent_overload_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, program.body);
        }
        if (self.options.typescript_eslint_unified_signatures) {
            try typescript_eslint_unified_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, program.body);
        }
        return .proceed;
    }

    pub fn enter_function(
        self: *BasicVisitor,
        function: ast.Function,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_dupe_args) {
            try no_dupe_args.check(self.allocator, self.diagnostics, ctx.tree, function);
        }
        if (self.options.no_param_reassign) {
            try no_param_reassign.checkFunction(self.allocator, self.diagnostics, ctx.tree, function);
        }
        if (self.options.no_inner_declarations) {
            try no_inner_declarations.checkFunction(self.allocator, self.diagnostics, ctx.tree, function, index, ctx);
        }
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkFunction(self.allocator, self.diagnostics, ctx.tree, function);
        }
        if (self.options.require_yield) {
            try require_yield.check(self.allocator, self.diagnostics, ctx.tree, function, index);
        }
        if (self.options.prefer_rest_params) {
            try prefer_rest_params.check(self.allocator, self.diagnostics, ctx.tree, function, index);
        }
        if (self.options.react_jsx_no_bind) {
            try react_jsx_no_bind.checkFunctionDeclaration(self.allocator, ctx.tree, function, &self.react_jsx_no_bind_state);
        }
        return .proceed;
    }

    pub fn enter_class(
        self: *BasicVisitor,
        class: ast.Class,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.constructor_super) {
            try constructor_super.checkClass(self.allocator, self.diagnostics, ctx.tree, class);
        }
        if (self.options.react_require_render_return) {
            try react_require_render_return.checkClass(self.allocator, self.diagnostics, ctx.tree, class, self.react_require_render_return_state);
        }
        if (self.options.react_no_multi_comp) {
            try react_no_multi_comp.checkClass(self.allocator, self.diagnostics, ctx.tree, class, index, &self.react_no_multi_comp_state);
        }
        if (self.options.react_no_redundant_should_component_update) {
            try react_no_redundant_should_component_update.checkClass(self.allocator, self.diagnostics, ctx.tree, class, index, ctx.path.parent());
        }
        if (self.options.no_this_before_super) {
            try no_this_before_super.checkClass(self.allocator, self.diagnostics, ctx.tree, class);
        }
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkBinding(self.allocator, self.diagnostics, ctx.tree, class.id, false);
        }
        if (self.options.no_useless_constructor and !self.options.typescript_eslint_no_useless_constructor) {
            try no_useless_constructor.checkClass(self.allocator, self.diagnostics, ctx.tree, class);
        }
        if (self.options.typescript_eslint_no_useless_constructor) {
            try typescript_eslint_no_useless_constructor.checkClass(self.allocator, self.diagnostics, ctx.tree, class);
        }
        if (self.options.typescript_eslint_no_misused_new) {
            try typescript_eslint_no_misused_new.checkClass(self.allocator, self.diagnostics, ctx.tree, class);
        }
        return .proceed;
    }

    pub fn enter_if_statement(
        self: *BasicVisitor,
        statement: ast.IfStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.curly) {
            try curly.checkIfStatement(self.allocator, self.diagnostics, ctx.tree, statement);
        }
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
        if (self.options.curly) {
            try curly.checkBody(self.allocator, self.diagnostics, ctx.tree, statement.body);
        }
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
        if (self.options.curly) {
            try curly.checkBody(self.allocator, self.diagnostics, ctx.tree, statement.body);
        }
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
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.curly) {
            try curly.checkBody(self.allocator, self.diagnostics, ctx.tree, statement.body);
        }
        if (self.options.no_cond_assign and statement.@"test" != .null) {
            try no_cond_assign.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        if (self.options.no_constant_condition and statement.@"test" != .null) {
            try no_constant_condition.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        if (self.options.for_direction) {
            try for_direction.check(self.allocator, self.diagnostics, ctx.tree, statement, index);
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
        if (self.options.no_extra_semi and !self.options.typescript_eslint_no_extra_semi) {
            try no_extra_semi.check(self.allocator, self.diagnostics, ctx.tree, index, ctx);
        }
        if (self.options.typescript_eslint_no_extra_semi) {
            try typescript_eslint_no_extra_semi.check(self.allocator, self.diagnostics, ctx.tree, index, ctx);
        }
        return .proceed;
    }

    pub fn enter_expression_statement(
        self: *BasicVisitor,
        statement: ast.ExpressionStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_unused_expressions and !self.options.typescript_eslint_no_unused_expressions) {
            try no_unused_expressions.check(self.allocator, self.diagnostics, ctx.tree, statement, index);
        }
        if (self.options.typescript_eslint_no_unused_expressions) {
            try typescript_eslint_no_unused_expressions.check(self.allocator, self.diagnostics, ctx.tree, statement, index);
        }
        return .proceed;
    }

    pub fn enter_ts_as_expression(
        self: *BasicVisitor,
        expression: ast.TSAsExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_consistent_type_assertions) {
            try typescript_eslint_consistent_type_assertions.checkAsExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.typescript_eslint_prefer_as_const) {
            try typescript_eslint_prefer_as_const.checkAsExpression(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        return .proceed;
    }

    pub fn enter_ts_type_assertion(
        self: *BasicVisitor,
        assertion: ast.TSTypeAssertion,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_consistent_type_assertions) {
            try typescript_eslint_consistent_type_assertions.checkTypeAssertion(self.allocator, self.diagnostics, ctx.tree, assertion, index);
        }
        if (self.options.typescript_eslint_prefer_as_const) {
            try typescript_eslint_prefer_as_const.checkTypeAssertion(self.allocator, self.diagnostics, ctx.tree, assertion);
        }
        return .proceed;
    }

    pub fn enter_ts_array_type(
        self: *BasicVisitor,
        array_type: ast.TSArrayType,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_array_type) {
            try typescript_eslint_array_type.checkArrayType(self.allocator, self.diagnostics, ctx.tree, array_type, index);
        }
        return .proceed;
    }

    pub fn enter_variable_declarator(
        self: *BasicVisitor,
        declarator: ast.VariableDeclarator,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_prefer_as_const) {
            try typescript_eslint_prefer_as_const.checkVariableDeclarator(self.allocator, self.diagnostics, ctx.tree, declarator);
        }
        if (self.options.typescript_eslint_no_this_alias) {
            try typescript_eslint_no_this_alias.checkVariableDeclarator(self.allocator, self.diagnostics, ctx.tree, declarator);
        }
        if (self.options.typescript_eslint_no_inferrable_types) {
            try typescript_eslint_no_inferrable_types.checkVariableDeclarator(self.allocator, self.diagnostics, ctx.tree, declarator);
        }
        if (self.options.react_no_children_prop) {
            react_no_children_prop.checkVariableDeclarator(ctx.tree, declarator, &self.react_no_children_prop_bindings);
        }
        if (self.options.react_no_danger_with_children) {
            react_no_danger_with_children.checkVariableDeclarator(ctx.tree, declarator, &self.react_no_danger_with_children_bindings);
        }
        if (self.options.react_style_prop_object) {
            react_style_prop_object.checkVariableDeclarator(ctx.tree, declarator, &self.react_style_prop_object_bindings);
        }
        if (self.options.react_void_dom_elements_no_children) {
            react_void_dom_elements_no_children.checkVariableDeclarator(ctx.tree, declarator, &self.react_void_dom_elements_no_children_bindings);
        }
        if (self.options.react_jsx_no_bind) {
            try react_jsx_no_bind.checkVariableDeclarator(self.allocator, ctx.tree, declarator, ctx.path.ancestor(1), &self.react_jsx_no_bind_state);
        }
        return .proceed;
    }

    pub fn enter_assignment_pattern(
        self: *BasicVisitor,
        pattern: ast.AssignmentPattern,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_no_inferrable_types) {
            try typescript_eslint_no_inferrable_types.checkAssignmentPattern(self.allocator, self.diagnostics, ctx.tree, pattern);
        }
        return .proceed;
    }

    pub fn enter_ts_interface_declaration(
        self: *BasicVisitor,
        interface_declaration: ast.TSInterfaceDeclaration,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_no_empty_interface) {
            try typescript_eslint_no_empty_interface.check(self.allocator, self.diagnostics, ctx.tree, interface_declaration);
        }
        if (self.options.typescript_eslint_no_misused_new) {
            try typescript_eslint_no_misused_new.checkInterfaceDeclaration(self.allocator, self.diagnostics, ctx.tree, interface_declaration);
        }
        return .proceed;
    }

    pub fn enter_ts_type_alias_declaration(
        self: *BasicVisitor,
        declaration: ast.TSTypeAliasDeclaration,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_consistent_type_definitions) {
            try typescript_eslint_consistent_type_definitions.check(self.allocator, self.diagnostics, ctx.tree, declaration, index);
        }
        return .proceed;
    }

    pub fn enter_ts_interface_body(
        self: *BasicVisitor,
        body: ast.TSInterfaceBody,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_adjacent_overload_signatures) {
            try typescript_eslint_adjacent_overload_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, body.body);
        }
        if (self.options.typescript_eslint_unified_signatures) {
            try typescript_eslint_unified_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, body.body);
        }
        return .proceed;
    }

    pub fn enter_ts_method_signature(
        self: *BasicVisitor,
        signature: ast.TSMethodSignature,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_method_signature_style) {
            try typescript_eslint_method_signature_style.check(self.allocator, self.diagnostics, ctx.tree, signature, index);
        }
        return .proceed;
    }

    pub fn enter_ts_type_literal(
        self: *BasicVisitor,
        type_literal: ast.TSTypeLiteral,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_adjacent_overload_signatures) {
            try typescript_eslint_adjacent_overload_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, type_literal.members);
        }
        if (self.options.typescript_eslint_unified_signatures) {
            try typescript_eslint_unified_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, type_literal.members);
        }
        if (self.options.typescript_eslint_no_misused_new) {
            try typescript_eslint_no_misused_new.checkTypeLiteral(self.allocator, self.diagnostics, ctx.tree, type_literal);
        }
        return .proceed;
    }

    pub fn enter_ts_property_signature(
        self: *BasicVisitor,
        signature: ast.TSPropertySignature,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_typedef) {
            try typescript_eslint_typedef.checkPropertySignature(self.allocator, self.diagnostics, ctx.tree, signature, index);
        }
        return .proceed;
    }

    pub fn enter_ts_type_reference(
        self: *BasicVisitor,
        reference: ast.TSTypeReference,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_array_type) {
            try typescript_eslint_array_type.checkTypeReference(self.allocator, self.diagnostics, ctx.tree, reference, index);
        }
        if (self.options.typescript_eslint_ban_types) {
            try typescript_eslint_ban_types.checkTypeReference(self.allocator, self.diagnostics, ctx.tree, reference);
        }
        return .proceed;
    }

    pub fn enter_ts_module_block(
        self: *BasicVisitor,
        block: ast.TSModuleBlock,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_adjacent_overload_signatures) {
            try typescript_eslint_adjacent_overload_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, block.body);
        }
        if (self.options.typescript_eslint_unified_signatures) {
            try typescript_eslint_unified_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, block.body);
        }
        return .proceed;
    }

    pub fn enter_ts_non_null_expression(
        self: *BasicVisitor,
        expression: ast.TSNonNullExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_no_extra_non_null_assertion) {
            try typescript_eslint_no_extra_non_null_assertion.checkNonNullExpression(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        return .proceed;
    }

    pub fn enter_ts_type_parameter(
        self: *BasicVisitor,
        parameter: ast.TSTypeParameter,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_no_unnecessary_type_constraint) {
            try typescript_eslint_no_unnecessary_type_constraint.check(self.allocator, self.diagnostics, ctx.tree, parameter, index);
        }
        return .proceed;
    }

    pub fn enter_ts_void_keyword(
        self: *BasicVisitor,
        _: ast.TSVoidKeyword,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_no_invalid_void_type) {
            try typescript_eslint_no_invalid_void_type.check(self.allocator, self.diagnostics, ctx.tree, index, ctx);
        }
        return .proceed;
    }

    pub fn enter_ts_module_declaration(
        self: *BasicVisitor,
        declaration: ast.TSModuleDeclaration,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_prefer_namespace_keyword) {
            try typescript_eslint_prefer_namespace_keyword.check(self.allocator, self.diagnostics, ctx.tree, declaration, index);
        }
        if (self.options.typescript_eslint_no_namespace) {
            try typescript_eslint_no_namespace.check(self.allocator, self.diagnostics, ctx.tree, declaration, index);
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
        if (self.options.no_fallthrough) {
            try no_fallthrough.check(self.allocator, self.diagnostics, ctx.tree, statement);
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
        if (self.options.curly) {
            try curly.checkBody(self.allocator, self.diagnostics, ctx.tree, statement.body);
        }
        if (self.options.guard_for_in) {
            try guard_for_in.check(self.allocator, self.diagnostics, ctx.tree, statement, index);
        }
        if (self.options.no_for_in) {
            try no_for_in.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_for_of_statement(
        self: *BasicVisitor,
        statement: ast.ForOfStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.curly) {
            try curly.checkBody(self.allocator, self.diagnostics, ctx.tree, statement.body);
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
        if (self.options.typescript_eslint_adjacent_overload_signatures) {
            try typescript_eslint_adjacent_overload_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, block.body);
        }
        if (self.options.react_jsx_no_bind) {
            try react_jsx_no_bind.enterBlock(self.allocator, &self.react_jsx_no_bind_state);
        }
        return .proceed;
    }

    pub fn exit_block_statement(self: *BasicVisitor, _: ast.BlockStatement, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        if (self.options.react_jsx_no_bind) {
            react_jsx_no_bind.exitBlock(self.allocator, &self.react_jsx_no_bind_state);
        }
    }

    pub fn enter_function_body(
        self: *BasicVisitor,
        body: ast.FunctionBody,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.react_jsx_no_bind) {
            try react_jsx_no_bind.enterBlock(self.allocator, &self.react_jsx_no_bind_state);
        }
        if (self.options.no_empty_block_statements) {
            try no_empty_block_statements.checkFunctionBody(self.allocator, self.diagnostics, ctx.tree, body, index);
        }
        if (self.options.no_empty_function and !self.options.typescript_eslint_no_empty_function) {
            try no_empty_function.check(self.allocator, self.diagnostics, ctx.tree, body, index);
        }
        if (self.options.typescript_eslint_no_empty_function) {
            try typescript_eslint_no_empty_function.checkFunctionBody(self.allocator, self.diagnostics, ctx.tree, body, index, ctx);
        }
        if (self.options.getter_return) {
            try getter_return.check(self.allocator, self.diagnostics, ctx.tree, body, index, ctx);
        }
        if (self.options.no_unreachable) {
            try no_unreachable.checkRange(self.allocator, self.diagnostics, ctx.tree, body.body);
        }
        return .proceed;
    }

    pub fn exit_function_body(self: *BasicVisitor, _: ast.FunctionBody, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        if (self.options.react_jsx_no_bind) {
            react_jsx_no_bind.exitBlock(self.allocator, &self.react_jsx_no_bind_state);
        }
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
        if (self.options.one_var) {
            try one_var.check(self.allocator, self.diagnostics, ctx.tree, declaration, index, ctx);
        }
        if (self.options.prefer_destructuring) {
            try prefer_destructuring.checkVariableDeclaration(self.allocator, self.diagnostics, ctx.tree, declaration);
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
        if (self.options.no_nonoctal_decimal_escape) {
            try no_nonoctal_decimal_escape.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        if (self.options.no_octal_escape) {
            try no_octal_escape.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        if (self.options.no_template_curly_in_string) {
            try no_template_curly_in_string.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        if (self.options.no_useless_escape) {
            try no_useless_escape.checkStringLiteral(self.allocator, self.diagnostics, ctx.tree, index);
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
        if (self.options.no_useless_escape) {
            try no_useless_escape.checkTemplateLiteral(self.allocator, self.diagnostics, ctx.tree, literal);
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
        if (self.options.no_loss_of_precision and !self.options.typescript_eslint_no_loss_of_precision) {
            try no_loss_of_precision.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        if (self.options.typescript_eslint_no_loss_of_precision) {
            try typescript_eslint_no_loss_of_precision.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
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
        if (self.options.no_param_reassign) {
            try no_param_reassign.checkArrowFunction(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        return .proceed;
    }

    pub fn enter_assignment_expression(
        self: *BasicVisitor,
        expression: ast.AssignmentExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_bitwise) {
            try no_bitwise.checkAssignmentExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_multi_assign) {
            try no_multi_assign.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.operator_assignment) {
            try operator_assignment.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_self_assign) {
            try no_self_assign.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_implicit_coercion) {
            try no_implicit_coercion.checkAssignmentExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.typescript_eslint_no_confusing_non_null_assertion) {
            try typescript_eslint_no_confusing_non_null_assertion.checkAssignmentExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.typescript_eslint_no_this_alias) {
            try typescript_eslint_no_this_alias.checkAssignmentExpression(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        return .proceed;
    }

    pub fn enter_binary_expression(
        self: *BasicVisitor,
        expression: ast.BinaryExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_bitwise) {
            try no_bitwise.checkBinaryExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.typescript_eslint_restrict_plus_operands) {
            try typescript_eslint_restrict_plus_operands.checkBinaryExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
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
        if (self.options.valid_typeof) {
            try valid_typeof.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_useless_concat) {
            try no_useless_concat.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.prefer_template) {
            try prefer_template.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
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
        if (self.options.typescript_eslint_no_confusing_non_null_assertion) {
            try typescript_eslint_no_confusing_non_null_assertion.checkBinaryExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        return .proceed;
    }

    pub fn enter_unary_expression(
        self: *BasicVisitor,
        expression: ast.UnaryExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_bitwise) {
            try no_bitwise.checkUnaryExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
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
        if (self.options.array_callback_return) {
            try array_callback_return.check(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        if (self.options.import_no_amd) {
            try import_no_amd.check(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
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
        if (self.options.react_no_find_dom_node) {
            try react_no_find_dom_node.check(self.allocator, self.diagnostics, ctx.tree, call);
        }
        if (self.options.react_no_is_mounted) {
            try react_no_is_mounted.check(self.allocator, self.diagnostics, ctx.tree, call, ctx);
        }
        if (self.options.react_no_render_return_value) {
            try react_no_render_return_value.check(self.allocator, self.diagnostics, ctx.tree, call, ctx);
        }
        if (self.options.react_no_will_update_set_state) {
            try react_no_will_update_set_state.check(self.allocator, self.diagnostics, ctx.tree, call, ctx);
        }
        if (self.options.react_button_has_type) {
            try react_button_has_type.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index, self.react_button_has_type_state);
        }
        if (self.options.react_require_render_return) {
            try react_require_render_return.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index, self.react_require_render_return_state);
        }
        if (self.options.react_no_children_prop) {
            try react_no_children_prop.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index, self.react_no_children_prop_bindings);
        }
        if (self.options.react_no_danger_with_children) {
            try react_no_danger_with_children.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index, &self.react_no_danger_with_children_bindings);
        }
        if (self.options.react_style_prop_object) {
            try react_style_prop_object.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, &self.react_style_prop_object_bindings);
        }
        if (self.options.react_void_dom_elements_no_children) {
            try react_void_dom_elements_no_children.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index, self.react_void_dom_elements_no_children_bindings);
        }
        if (self.options.react_no_array_index_key) {
            try react_no_array_index_key.enterCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index, &self.react_no_array_index_key_state);
        }
        if (self.options.react_jsx_key) {
            try react_jsx_key.enterCallExpression(self.allocator, self.diagnostics, ctx.tree, call, &self.react_jsx_key_state);
        }
        if (self.options.new_cap) {
            try new_cap.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        if (self.options.no_extra_bind) {
            try no_extra_bind.check(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        if (self.options.prefer_spread) {
            try prefer_spread.check(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        if (self.options.typescript_eslint_no_extra_non_null_assertion) {
            try typescript_eslint_no_extra_non_null_assertion.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call);
        }
        if (self.options.typescript_eslint_no_array_constructor) {
            try typescript_eslint_no_array_constructor.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        return .proceed;
    }

    pub fn exit_call_expression(
        self: *BasicVisitor,
        call: ast.CallExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        if (self.options.react_no_array_index_key) {
            react_no_array_index_key.exitCallExpression(ctx.tree, call, &self.react_no_array_index_key_state);
        }
        if (self.options.react_jsx_key) {
            react_jsx_key.exitCallExpression(ctx.tree, call, &self.react_jsx_key_state);
        }
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
        if (self.options.new_cap) {
            try new_cap.checkNewExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.new_parens) {
            try new_parens.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.typescript_eslint_no_array_constructor) {
            try typescript_eslint_no_array_constructor.checkNewExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
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
        if (self.options.dot_notation and !self.options.typescript_eslint_dot_notation) {
            try dot_notation.check(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
        if (self.options.typescript_eslint_dot_notation) {
            try typescript_eslint_dot_notation.check(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
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
        if (self.options.react_no_this_in_sfc) {
            try react_no_this_in_sfc.check(self.allocator, self.diagnostics, ctx.tree, member, index, ctx);
        }
        if (self.options.typescript_eslint_no_extra_non_null_assertion) {
            try typescript_eslint_no_extra_non_null_assertion.checkMemberExpression(self.allocator, self.diagnostics, ctx.tree, member);
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
        if (self.options.react_jsx_key and self.react_jsx_key_state.children_to_array_depth == 0) {
            try react_jsx_key.checkArrayExpression(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        return .proceed;
    }

    pub fn enter_jsx_attribute(
        self: *BasicVisitor,
        attribute: ast.JSXAttribute,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.jsx_a11y_aria_props) {
            try jsx_a11y_aria_props.check(self.allocator, self.diagnostics, ctx.tree, attribute, index);
        }
        if (self.options.jsx_a11y_aria_proptypes) {
            try jsx_a11y_aria_proptypes.check(self.allocator, self.diagnostics, ctx.tree, attribute, index);
        }
        if (self.options.react_no_danger) {
            try react_no_danger.check(self.allocator, self.diagnostics, ctx.tree, attribute, index, ctx.path.ancestor(1));
        }
        if (self.options.react_jsx_boolean_value) {
            try react_jsx_boolean_value.check(self.allocator, self.diagnostics, ctx.tree, attribute, index);
        }
        if (self.options.react_style_prop_object) {
            try react_style_prop_object.checkJSXAttribute(self.allocator, self.diagnostics, ctx.tree, attribute, index, ctx.path.ancestor(1), &self.react_style_prop_object_bindings);
        }
        if (self.options.react_no_children_prop) {
            try react_no_children_prop.checkJSXAttribute(self.allocator, self.diagnostics, ctx.tree, attribute, index);
        }
        if (self.options.react_no_string_refs) {
            try react_no_string_refs.check(self.allocator, self.diagnostics, ctx.tree, attribute, index);
        }
        if (self.options.react_no_array_index_key) {
            try react_no_array_index_key.checkJSXAttribute(self.allocator, self.diagnostics, ctx.tree, attribute, self.react_no_array_index_key_state);
        }
        if (self.options.react_jsx_no_bind) {
            try react_jsx_no_bind.checkJSXAttribute(self.allocator, self.diagnostics, ctx.tree, attribute, index, self.react_jsx_no_bind_state);
        }
        return .proceed;
    }

    pub fn enter_jsx_element(
        self: *BasicVisitor,
        element: ast.JSXElement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.react_no_children_prop) {
            try react_no_children_prop.checkJSXElement(self.allocator, self.diagnostics, ctx.tree, element, index);
        }
        if (self.options.react_button_has_type) {
            try react_button_has_type.checkJSXElement(self.allocator, self.diagnostics, ctx.tree, element, index);
        }
        if (self.options.react_no_danger_with_children) {
            try react_no_danger_with_children.checkJSXElement(self.allocator, self.diagnostics, ctx.tree, element, index, &self.react_no_danger_with_children_bindings);
        }
        if (self.options.jsx_a11y_alt_text) {
            try jsx_a11y_alt_text.checkElement(self.allocator, self.diagnostics, ctx.tree, element, index);
        }
        if (self.options.jsx_a11y_anchor_has_content) {
            try jsx_a11y_anchor_has_content.check(self.allocator, self.diagnostics, ctx.tree, element, index);
        }
        if (self.options.react_void_dom_elements_no_children) {
            try react_void_dom_elements_no_children.checkJSXElement(self.allocator, self.diagnostics, ctx.tree, element, index);
        }
        return .proceed;
    }

    pub fn enter_jsx_opening_element(
        self: *BasicVisitor,
        opening: ast.JSXOpeningElement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.react_jsx_no_duplicate_props) {
            try react_jsx_no_duplicate_props.check(self.allocator, self.diagnostics, ctx.tree, opening);
        }
        if (self.options.jsx_a11y_alt_text) {
            try jsx_a11y_alt_text.checkOpeningElement(self.allocator, self.diagnostics, ctx.tree, opening, index);
        }
        if (self.options.jsx_a11y_no_access_key) {
            try jsx_a11y_no_access_key.check(self.allocator, self.diagnostics, ctx.tree, opening, index);
        }
        if (self.options.jsx_a11y_iframe_has_title) {
            try jsx_a11y_iframe_has_title.check(self.allocator, self.diagnostics, ctx.tree, opening, index);
        }
        if (self.options.jsx_a11y_img_redundant_alt) {
            try jsx_a11y_img_redundant_alt.check(self.allocator, self.diagnostics, ctx.tree, opening, index);
        }
        if (self.options.jsx_a11y_no_distracting_elements) {
            try jsx_a11y_no_distracting_elements.check(self.allocator, self.diagnostics, ctx.tree, opening, index);
        }
        if (self.options.jsx_a11y_aria_unsupported_elements) {
            try jsx_a11y_aria_unsupported_elements.check(self.allocator, self.diagnostics, ctx.tree, opening, index);
        }
        if (self.options.jsx_a11y_aria_role) {
            try jsx_a11y_aria_role.check(self.allocator, self.diagnostics, ctx.tree, opening);
        }
        if (self.options.jsx_a11y_role_has_required_aria_props) {
            try jsx_a11y_role_has_required_aria_props.check(self.allocator, self.diagnostics, ctx.tree, opening);
        }
        if (self.options.jsx_a11y_role_supports_aria_props) {
            try jsx_a11y_role_supports_aria_props.check(self.allocator, self.diagnostics, ctx.tree, opening, index);
        }
        if (self.options.jsx_a11y_scope) {
            try jsx_a11y_scope.check(self.allocator, self.diagnostics, ctx.tree, opening, index);
        }
        if (self.options.react_jsx_no_target_blank) {
            try react_jsx_no_target_blank.check(self.allocator, self.diagnostics, ctx.tree, opening, index);
        }
        if (self.options.react_jsx_pascal_case) {
            try react_jsx_pascal_case.check(self.allocator, self.diagnostics, ctx.tree, opening, index);
        }
        if (self.options.react_self_closing_comp) {
            try react_self_closing_comp.check(self.allocator, self.diagnostics, ctx.tree, opening, index, ctx.path.ancestor(1));
        }
        return .proceed;
    }

    pub fn enter_jsx_text(
        self: *BasicVisitor,
        text: ast.JSXText,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.react_jsx_no_comment_textnodes) {
            try react_jsx_no_comment_textnodes.check(self.allocator, self.diagnostics, ctx.tree, text, index);
        }
        if (self.options.react_no_unescaped_entities) {
            try react_no_unescaped_entities.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_object_expression(
        self: *BasicVisitor,
        expression: ast.ObjectExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_dupe_keys) {
            try no_dupe_keys.check(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        if (self.options.no_useless_computed_key) {
            try no_useless_computed_key.checkObjectExpression(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        if (self.options.react_prefer_es6_class) {
            try react_prefer_es6_class.checkObjectExpression(self.allocator, self.diagnostics, ctx.tree, index, ctx.path.ancestor(1));
        }
        return .proceed;
    }

    pub fn enter_object_property(
        self: *BasicVisitor,
        property: ast.ObjectProperty,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.object_shorthand) {
            try object_shorthand.check(self.allocator, self.diagnostics, ctx.tree, property, index);
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
        if (self.options.no_dupe_class_members and !self.options.typescript_eslint_no_dupe_class_members) {
            try no_dupe_class_members.check(self.allocator, self.diagnostics, ctx.tree, body);
        }
        if (self.options.typescript_eslint_no_dupe_class_members) {
            try typescript_eslint_no_dupe_class_members.check(self.allocator, self.diagnostics, ctx.tree, body);
        }
        if (self.options.typescript_eslint_member_ordering) {
            try typescript_eslint_member_ordering.check(self.allocator, self.diagnostics, ctx.tree, body);
        }
        if (self.options.typescript_eslint_adjacent_overload_signatures) {
            try typescript_eslint_adjacent_overload_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, body.body);
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
        if (self.options.typescript_eslint_explicit_member_accessibility) {
            try typescript_eslint_explicit_member_accessibility.checkMethodDefinition(self.allocator, self.diagnostics, ctx.tree, method, index);
        }
        if (self.options.typescript_eslint_class_literal_property_style) {
            try typescript_eslint_class_literal_property_style.checkMethodDefinition(self.allocator, self.diagnostics, ctx.tree, method, index);
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
        if (self.options.typescript_eslint_explicit_member_accessibility) {
            try typescript_eslint_explicit_member_accessibility.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property, index);
        }
        if (self.options.typescript_eslint_prefer_as_const) {
            try typescript_eslint_prefer_as_const.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property);
        }
        if (self.options.typescript_eslint_no_inferrable_types) {
            try typescript_eslint_no_inferrable_types.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property);
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
        if (self.options.no_misleading_character_class) {
            try no_misleading_character_class.checkRegExpLiteral(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        if (self.options.no_regex_spaces) {
            try no_regex_spaces.check(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        if (self.options.no_useless_escape) {
            try no_useless_escape.checkRegExpLiteral(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        return .proceed;
    }
};
