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
pub const accessor_pairs = @import("accessor_pairs.zig");
pub const array_callback_return = @import("array_callback_return.zig");
pub const block_scoped_var = @import("block_scoped_var.zig");
pub const capitalized_comments = @import("capitalized_comments.zig");
pub const consistent_return = @import("consistent_return.zig");
pub const constructor_super = @import("constructor_super.zig");
pub const dot_notation = @import("dot_notation.zig");
pub const default_case = @import("default_case.zig");
pub const default_case_last = @import("default_case_last.zig");
pub const default_param_last = @import("default_param_last.zig");
pub const eol_last = @import("eol_last.zig");
pub const eslint_comments_no_restricted_disable = @import("eslint_comments_no_restricted_disable.zig");
pub const for_direction = @import("for_direction.zig");
pub const func_name_matching = @import("func_name_matching.zig");
pub const func_names = @import("func_names.zig");
pub const getter_return = @import("getter_return.zig");
pub const grouped_accessor_pairs = @import("grouped_accessor_pairs.zig");
pub const guard_for_in = @import("guard_for_in.zig");
pub const alipay_ant_disallow_typos = @import("alipay_ant_disallow_typos.zig");
pub const alipay_ant_exhaustive_deps = @import("alipay_ant_exhaustive_deps.zig");
pub const alipay_ant_jsx_handler_names = @import("alipay_ant_jsx_handler_names.zig");
pub const alipay_ant_no_deprecated_dependence = @import("alipay_ant_no_deprecated_dependence.zig");
pub const alipay_ant_no_deprecated_variable = @import("alipay_ant_no_deprecated_variable.zig");
pub const alipay_ant_no_import_files_from_pages_in_common = @import("alipay_ant_no_import_files_from_pages_in_common.zig");
pub const alipay_ant_no_negative_conditionals = @import("alipay_ant_no_negative_conditionals.zig");
pub const alipay_ant_no_import_src = @import("alipay_ant_no_import_src.zig");
pub const alipay_ant_no_phantom_dependencies = @import("alipay_ant_no_phantom_dependencies.zig");
pub const alipay_ant_no_too_large_file = @import("alipay_ant_no_too_large_file.zig");
pub const alipay_ant_prefer_elseif_end_with_else = @import("alipay_ant_prefer_elseif_end_with_else.zig");
pub const alipay_ant_prefer_catch_unsafe_func_call = @import("alipay_ant_prefer_catch_unsafe_func_call.zig");
pub const alipay_ant_prefer_click_with_debounce = @import("alipay_ant_prefer_click_with_debounce.zig");
pub const alipay_ant_prefer_import_as_required = @import("alipay_ant_prefer_import_as_required.zig");
pub const alipay_ant_no_spread_params = @import("alipay_ant_no_spread_params.zig");
pub const alipay_ant_prefer_managed_resource = @import("alipay_ant_prefer_managed_resource.zig");
pub const alipay_ant_prefer_safe_image_renderer = @import("alipay_ant_prefer_safe_image_renderer.zig");
pub const alipay_ant_prefer_import_from_stdlib = @import("alipay_ant_prefer_import_from_stdlib.zig");
pub const alipay_spmlint_use_labeled_spm = @import("alipay_spmlint_use_labeled_spm.zig");
pub const alipay_spmlint_valid_manual_click = @import("alipay_spmlint_valid_manual_click.zig");
pub const alipay_spmlint_valid_manual_expo = @import("alipay_spmlint_valid_manual_expo.zig");
pub const alipay_spmlint_valid_manual_param = @import("alipay_spmlint_valid_manual_param.zig");
pub const alipay_spmlint_valid_manual_pv = @import("alipay_spmlint_valid_manual_pv.zig");
pub const import_first = @import("import_first.zig");
pub const import_default = @import("import_default.zig");
pub const import_export = @import("import_export.zig");
pub const import_named = @import("import_named.zig");
pub const import_namespace = @import("import_namespace.zig");
pub const import_newline_after_import = @import("import_newline_after_import.zig");
pub const import_no_amd = @import("import_no_amd.zig");
pub const import_no_cycle = @import("import_no_cycle.zig");
pub const import_no_duplicates = @import("import_no_duplicates.zig");
pub const import_no_named_as_default = @import("import_no_named_as_default.zig");
pub const import_no_named_as_default_member = @import("import_no_named_as_default_member.zig");
pub const import_no_unresolved = @import("import_no_unresolved.zig");
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
pub const logical_assignment_operators = @import("logical_assignment_operators.zig");
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
pub const no_confusing_arrow = @import("no_confusing_arrow.zig");
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
pub const no_underscore_dangle = @import("no_underscore_dangle.zig");
pub const no_undefined = @import("no_undefined.zig");
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
pub const prefer_numeric_literals = @import("prefer_numeric_literals.zig");
pub const prefer_object_has_own = @import("prefer_object_has_own.zig");
pub const prefer_object_spread = @import("prefer_object_spread.zig");
pub const prefer_promise_reject_errors = @import("prefer_promise_reject_errors.zig");
pub const prefer_regex_literals = @import("prefer_regex_literals.zig");
pub const prefer_rest_params = @import("prefer_rest_params.zig");
pub const prefer_spread = @import("prefer_spread.zig");
pub const prefer_template = @import("prefer_template.zig");
pub const react_default_props_match_prop_types = @import("react_default_props_match_prop_types.zig");
pub const react_button_has_type = @import("react_button_has_type.zig");
pub const react_display_name = @import("react_display_name.zig");
pub const react_jsx_boolean_value = @import("react_jsx_boolean_value.zig");
pub const react_jsx_filename_extension = @import("react_jsx_filename_extension.zig");
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
pub const react_no_access_state_in_setstate = @import("react_no_access_state_in_setstate.zig");
pub const react_no_deprecated = @import("react_no_deprecated.zig");
pub const react_forbid_prop_types = @import("react_forbid_prop_types.zig");
pub const react_no_children_prop = @import("react_no_children_prop.zig");
pub const react_no_array_index_key = @import("react_no_array_index_key.zig");
pub const react_no_find_dom_node = @import("react_no_find_dom_node.zig");
pub const react_no_is_mounted = @import("react_no_is_mounted.zig");
pub const react_no_multi_comp = @import("react_no_multi_comp.zig");
pub const react_no_redundant_should_component_update = @import("react_no_redundant_should_component_update.zig");
pub const react_no_render_return_value = @import("react_no_render_return_value.zig");
pub const react_no_this_in_sfc = @import("react_no_this_in_sfc.zig");
pub const react_no_typos = @import("react_no_typos.zig");
pub const react_no_unknown_property = @import("react_no_unknown_property.zig");
pub const react_prop_types = @import("react_prop_types.zig");
pub const react_no_unused_prop_types = @import("react_no_unused_prop_types.zig");
pub const react_no_unused_state = @import("react_no_unused_state.zig");
pub const react_no_will_update_set_state = @import("react_no_will_update_set_state.zig");
pub const react_require_render_return = @import("react_require_render_return.zig");
pub const react_no_string_refs = @import("react_no_string_refs.zig");
pub const react_no_unescaped_entities = @import("react_no_unescaped_entities.zig");
pub const react_prefer_es6_class = @import("react_prefer_es6_class.zig");
pub const react_style_prop_object = @import("react_style_prop_object.zig");
pub const react_self_closing_comp = @import("react_self_closing_comp.zig");
pub const react_void_dom_elements_no_children = @import("react_void_dom_elements_no_children.zig");
pub const react_hooks_rules_of_hooks = @import("react_hooks_rules_of_hooks.zig");
pub const radix = @import("radix.zig");
pub const require_await = @import("require_await.zig");
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
pub const typescript_eslint_no_duplicate_enum_values = @import("typescript_eslint_no_duplicate_enum_values.zig");
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
pub const typescript_eslint_no_unsafe_declaration_merging = @import("typescript_eslint_no_unsafe_declaration_merging.zig");
pub const typescript_eslint_triple_slash_reference = @import("typescript_eslint_triple_slash_reference.zig");
pub const typescript_eslint_typedef = @import("typescript_eslint_typedef.zig");
pub const typescript_eslint_unified_signatures = @import("typescript_eslint_unified_signatures.zig");
pub const typescript_eslint_no_unnecessary_parameter_property_assignment = @import("typescript_eslint_no_unnecessary_parameter_property_assignment.zig");
pub const typescript_eslint_no_unnecessary_type_constraint = @import("typescript_eslint_no_unnecessary_type_constraint.zig");
pub const typescript_eslint_no_useless_constructor = @import("typescript_eslint_no_useless_constructor.zig");
pub const typescript_eslint_no_useless_empty_export = @import("typescript_eslint_no_useless_empty_export.zig");
pub const typescript_eslint_no_unused_expressions = @import("typescript_eslint_no_unused_expressions.zig");
pub const typescript_eslint_no_unused_vars = @import("typescript_eslint_no_unused_vars.zig");
pub const typescript_eslint_no_use_before_define = @import("typescript_eslint_no_use_before_define.zig");
pub const typescript_eslint_no_var_requires = @import("typescript_eslint_no_var_requires.zig");
pub const typescript_eslint_no_wrapper_object_types = @import("typescript_eslint_no_wrapper_object_types.zig");
pub const typescript_eslint_prefer_as_const = @import("typescript_eslint_prefer_as_const.zig");
pub const typescript_eslint_prefer_namespace_keyword = @import("typescript_eslint_prefer_namespace_keyword.zig");
pub const typescript_eslint_restrict_plus_operands = @import("typescript_eslint_restrict_plus_operands.zig");
pub const unicode_bom = @import("unicode_bom.zig");
pub const use_isnan = @import("use_isnan.zig");
pub const valid_typeof = @import("valid_typeof.zig");
pub const vars_on_top = @import("vars_on_top.zig");
pub const wrap_iife = @import("wrap_iife.zig");
pub const yoda = @import("yoda.zig");

fn groupedAccessorPairsStyle(style: core.GroupedAccessorPairsStyle) grouped_accessor_pairs.Style {
    return switch (style) {
        .any_order => .any_order,
        .get_before_set => .get_before_set,
        .set_before_get => .set_before_get,
    };
}

fn funcNameMatchingStyle(style: core.FuncNameMatchingStyle) func_name_matching.Style {
    return switch (style) {
        .always => .always,
        .never => .never,
    };
}

fn reactPreferEs6ClassStyle(style: core.ReactPreferEs6ClassStyle) react_prefer_es6_class.Style {
    return switch (style) {
        .always => .always,
        .never => .never,
    };
}

fn reactDisplayNameOptions(options: core.Options) react_display_name.Options {
    return .{
        .check_context_objects = options.react_display_name_check_context_objects,
        .ignore_transpiler_name = options.react_display_name_ignore_transpiler_name,
    };
}

fn isCatchBody(tree: *const ast.Tree, index: ast.NodeIndex, parent: ?ast.NodeIndex) bool {
    const parent_index = parent orelse return false;
    return switch (tree.data(parent_index)) {
        .catch_clause => |clause| clause.body == index,
        else => false,
    };
}

fn emptyFunctionKind(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) no_empty_function.Kind {
    const parent_index = ctx.path.parent() orelse return .functions;

    const function = switch (tree.data(parent_index)) {
        .arrow_function_expression => return .arrowFunctions,
        .function => |function| function,
        else => return .functions,
    };

    const grandparent_index = ctx.path.ancestor(2) orelse return .functions;
    return switch (tree.data(grandparent_index)) {
        .method_definition => |method| methodKind(method.kind, function),
        .object_property => |property| if (property.method or property.kind != .init)
            propertyMethodKind(property.kind, function)
        else
            functionKind(function),
        else => functionKind(function),
    };
}

fn functionKind(function: ast.Function) no_empty_function.Kind {
    if (function.async) return .asyncFunctions;
    if (function.generator) return .generatorFunctions;
    return .functions;
}

fn methodKind(kind: ast.MethodDefinitionKind, function: ast.Function) no_empty_function.Kind {
    return switch (kind) {
        .constructor => .constructors,
        .get => .getters,
        .set => .setters,
        .method => methodFunctionKind(function),
    };
}

fn propertyMethodKind(kind: ast.PropertyKind, function: ast.Function) no_empty_function.Kind {
    return switch (kind) {
        .get => .getters,
        .set => .setters,
        else => methodFunctionKind(function),
    };
}

fn methodFunctionKind(function: ast.Function) no_empty_function.Kind {
    if (function.async) return .asyncMethods;
    if (function.generator) return .generatorMethods;
    return .methods;
}

pub fn runBasic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
    options: core.Options,
) Allocator.Error!void {
    if (options.capitalized_comments) {
        try capitalized_comments.runWithOptions(allocator, diagnostics, tree, .{
            .mode = switch (options.capitalized_comments_mode) {
                .always => .always,
                .never => .never,
            },
            .ignore_inline_comments = options.capitalized_comments_ignore_inline_comments == .yes,
            .ignore_consecutive_comments = options.capitalized_comments_ignore_consecutive_comments == .yes,
        });
    }
    if (options.no_warning_comments) {
        try no_warning_comments.runWithOptions(allocator, diagnostics, tree, .{
            .location = switch (options.no_warning_comments_location) {
                .start => .start,
                .anywhere => .anywhere,
            },
            .decoration = switch (options.no_warning_comments_decoration) {
                .none => .none,
                .asterisk => .asterisk,
                .slash => .slash,
                .slash_asterisk => .slash_asterisk,
            },
            .terms = options.no_warning_comments_terms,
        });
    }
    if (options.no_trailing_spaces) {
        try no_trailing_spaces.runWithOptions(allocator, diagnostics, tree, .{
            .skip_blank_lines = options.no_trailing_spaces_skip_blank_lines,
            .ignore_comments = options.no_trailing_spaces_ignore_comments,
        });
    }
    if (options.eol_last) {
        try eol_last.runWithOptions(allocator, diagnostics, tree, .{
            .style = switch (options.eol_last_style) {
                .always => .always,
                .never => .never,
            },
        });
    }
    if (options.eslint_comments_no_restricted_disable) {
        try eslint_comments_no_restricted_disable.run(allocator, diagnostics, tree, options.eslint_comments_no_restricted_disable_no_nested_ternary);
    }
    if (options.unicode_bom) {
        try unicode_bom.runWithOptions(allocator, diagnostics, tree, .{
            .style = switch (options.unicode_bom_style) {
                .never => .never,
                .always => .always,
            },
        });
    }
    if (options.wrap_iife) {
        try wrap_iife.runWithStyle(allocator, diagnostics, tree, switch (options.wrap_iife_style) {
            .outside => .outside,
            .inside => .inside,
            .any => .any,
        });
    }
    if (options.no_tabs) {
        try no_tabs.runWithOptions(allocator, diagnostics, tree, .{
            .allow_indentation_tabs = options.no_tabs_allow_indentation_tabs,
        });
    }
    if (options.no_mixed_spaces_and_tabs) {
        try no_mixed_spaces_and_tabs.runWithOptions(allocator, diagnostics, tree, .{
            .smart_tabs = options.no_mixed_spaces_and_tabs_smart_tabs,
        });
    }
    if (options.linebreak_style) {
        try linebreak_style.runWithOptions(allocator, diagnostics, tree, .{
            .style = switch (options.linebreak_style_style) {
                .unix => .unix,
                .windows => .windows,
            },
        });
    }
    if (options.no_irregular_whitespace) {
        try no_irregular_whitespace.runWithOptions(allocator, diagnostics, tree, .{
            .skip_strings = options.no_irregular_whitespace_skip_strings,
            .skip_comments = options.no_irregular_whitespace_skip_comments,
            .skip_reg_exps = options.no_irregular_whitespace_skip_reg_exps,
            .skip_templates = options.no_irregular_whitespace_skip_templates,
            .skip_jsx_text = options.no_irregular_whitespace_skip_jsx_text,
        });
    }
    if (options.no_multiple_empty_lines) {
        try no_multiple_empty_lines.runWithOptions(allocator, diagnostics, tree, .{
            .max = options.no_multiple_empty_lines_max,
            .max_bof = options.no_multiple_empty_lines_max_bof,
            .max_eof = options.no_multiple_empty_lines_max_eof,
        });
    }
    if (options.no_inline_comments) {
        try no_inline_comments.runWithOptions(allocator, diagnostics, tree, .{
            .ignore_pattern = options.no_inline_comments_ignore_pattern,
        });
    }
    if (options.no_multi_spaces) {
        try no_multi_spaces.runWithOptions(allocator, diagnostics, tree, .{
            .ignore_eol_comments = options.no_multi_spaces_ignore_eol_comments,
            .exceptions = options.no_multi_spaces_exceptions,
        });
    }
    if (options.spaced_comment) {
        try spaced_comment.runWithOptions(allocator, diagnostics, tree, .{
            .style = switch (options.spaced_comment_style) {
                .always => .always,
                .never => .never,
            },
            .markers = options.spaced_comment_markers,
            .exceptions = options.spaced_comment_exceptions,
        });
    }
    if (options.typescript_eslint_ban_ts_comment) {
        try typescript_eslint_ban_ts_comment.runWithOptions(allocator, diagnostics, tree, .{
            .ts_expect_error = options.typescript_eslint_ban_ts_comment_ts_expect_error,
            .ts_ignore = options.typescript_eslint_ban_ts_comment_ts_ignore,
            .ts_nocheck = options.typescript_eslint_ban_ts_comment_ts_nocheck,
            .ts_check = options.typescript_eslint_ban_ts_comment_ts_check,
            .minimum_description_length = options.typescript_eslint_ban_ts_comment_minimum_description_length,
        });
    }
    if (options.typescript_eslint_ban_tslint_comment) {
        try typescript_eslint_ban_tslint_comment.run(allocator, diagnostics, tree);
    }
    if (options.typescript_eslint_triple_slash_reference) {
        try typescript_eslint_triple_slash_reference.runWithOptions(allocator, diagnostics, tree, .{
            .path = options.typescript_eslint_triple_slash_reference_path,
            .types = options.typescript_eslint_triple_slash_reference_types,
            .lib = options.typescript_eslint_triple_slash_reference_lib,
        });
    }
    if (options.alipay_ant_no_too_large_file) {
        try alipay_ant_no_too_large_file.run(allocator, diagnostics, tree, file_path);
    }
    if (options.typescript_eslint_no_non_null_asserted_optional_chain) {
        try typescript_eslint_no_non_null_asserted_optional_chain.run(allocator, diagnostics, tree);
    }
    if (options.react_hooks_rules_of_hooks) {
        try react_hooks_rules_of_hooks.run(allocator, diagnostics, tree);
    }
    if (options.require_await) {
        try require_await.run(allocator, diagnostics, tree);
    }
    if (options.react_prop_types) {
        try react_prop_types.run(allocator, diagnostics, tree, options.react_prop_types_skip_undeclared);
    }
    if (options.react_no_unused_prop_types) {
        try react_no_unused_prop_types.run(allocator, diagnostics, tree, options.react_no_unused_prop_types_skip_shape_props);
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
    defer visitor.react_no_access_state_in_setstate_state.deinit(allocator);
    defer visitor.react_no_typos_state.deinit(allocator);
    defer visitor.react_no_unused_state_state.deinit(allocator);
    defer visitor.react_display_name_state.deinit(allocator);
    defer visitor.react_forbid_prop_types_state.deinit(allocator);
    defer visitor.react_default_props_match_prop_types_state.deinit(allocator);

    try traverser.basic.traverse(BasicVisitor, tree, &visitor);
}

pub fn runSemantic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    io: ?std.Io,
    file_path: []const u8,
    semantic_result: traverser.semantic.Result,
    options: core.Options,
) Allocator.Error!void {
    if (options.alipay_ant_no_phantom_dependencies) {
        if (io) |actual_io| {
            try alipay_ant_no_phantom_dependencies.run(
                allocator,
                actual_io,
                diagnostics,
                tree,
                file_path,
                semantic_result.symbol_table,
            );
        }
    }

    if (options.alipay_ant_exhaustive_deps) {
        try alipay_ant_exhaustive_deps.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.alipay_ant_no_spread_params) {
        try alipay_ant_no_spread_params.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.alipay_ant_prefer_click_with_debounce) {
        try alipay_ant_prefer_click_with_debounce.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.alipay_ant_prefer_import_from_stdlib) {
        if (io) |actual_io| {
            try alipay_ant_prefer_import_from_stdlib.run(
                allocator,
                actual_io,
                diagnostics,
                tree,
                file_path,
            );
        }
    }

    if (options.import_default) {
        if (io) |actual_io| {
            try import_default.run(
                allocator,
                actual_io,
                diagnostics,
                tree,
                file_path,
            );
        }
    }
    if (options.import_export) {
        if (io) |actual_io| {
            try import_export.run(
                allocator,
                actual_io,
                diagnostics,
                tree,
                file_path,
            );
        }
    }
    if (options.import_named) {
        if (io) |actual_io| {
            try import_named.run(
                allocator,
                actual_io,
                diagnostics,
                tree,
                file_path,
            );
        }
    }
    if (options.import_namespace) {
        if (io) |actual_io| {
            try import_namespace.run(
                allocator,
                actual_io,
                diagnostics,
                tree,
                file_path,
                semantic_result.symbol_table,
            );
        }
    }
    if (options.import_no_cycle) {
        if (io) |actual_io| {
            try import_no_cycle.run(
                allocator,
                actual_io,
                diagnostics,
                tree,
                file_path,
            );
        }
    }
    if (options.import_no_named_as_default) {
        if (io) |actual_io| {
            try import_no_named_as_default.run(
                allocator,
                actual_io,
                diagnostics,
                tree,
                file_path,
            );
        }
    }
    if (options.import_no_named_as_default_member) {
        if (io) |actual_io| {
            try import_no_named_as_default_member.run(
                allocator,
                actual_io,
                diagnostics,
                tree,
                file_path,
            );
        }
    }
    if (options.import_no_unresolved) {
        if (io) |actual_io| {
            try import_no_unresolved.run(
                allocator,
                actual_io,
                diagnostics,
                tree,
                file_path,
            );
        }
    }

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

    if (options.no_console) {
        try no_console.run(allocator, diagnostics, tree, semantic_result.symbol_table, .{
            .allow = options.no_console_allow,
        });
    }

    if (options.no_extra_boolean_cast) {
        try no_extra_boolean_cast.runWithOptions(allocator, diagnostics, tree, .{
            .enforce_for_inner_expressions = options.no_extra_boolean_cast_enforce_for_inner_expressions,
        });
    }

    if (options.no_extend_native) {
        try no_extend_native.runWithOptions(allocator, diagnostics, tree, .{
            .exceptions = options.no_extend_native_exceptions,
        });
    }

    if (options.no_eval or options.no_alert or options.no_implied_eval) {
        try global_call_checks.run(
            allocator,
            diagnostics,
            tree,
            semantic_result.symbol_table,
            options.no_eval,
            options.no_eval_allow_indirect,
            options.no_alert,
            options.no_implied_eval,
        );
    }

    const use_typescript_no_redeclare = options.typescript_eslint_no_redeclare and tree.isTs();

    if (options.no_redeclare and !use_typescript_no_redeclare) {
        try no_redeclare.runWithOptions(allocator, diagnostics, tree, semantic_result.symbol_table, .{
            .builtin_globals = options.no_redeclare_builtin_globals == .yes,
        });
    }

    if (use_typescript_no_redeclare) {
        try typescript_eslint_no_redeclare.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.typescript_eslint_no_unsafe_declaration_merging and tree.isTs()) {
        try typescript_eslint_no_unsafe_declaration_merging.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    const use_typescript_no_shadow = options.typescript_eslint_no_shadow and tree.isTs();

    if (options.no_shadow and !use_typescript_no_shadow) {
        try no_shadow.runWithOptions(allocator, diagnostics, tree, semantic_result.scope_tree, semantic_result.symbol_table, .{
            .allow = options.no_shadow_allow,
            .builtin_globals = options.no_shadow_builtin_globals,
            .hoist = options.no_shadow_hoist,
        });
    }

    if (use_typescript_no_shadow) {
        try typescript_eslint_no_shadow.runWithOptions(allocator, diagnostics, tree, semantic_result.scope_tree, semantic_result.symbol_table, .{
            .allow = options.typescript_eslint_no_shadow_allow,
            .builtin_globals = options.typescript_eslint_no_shadow_builtin_globals,
            .hoist = options.typescript_eslint_no_shadow_hoist,
        });
    }

    if (reassignment_rules.shouldRun(options)) {
        try reassignment_rules.run(allocator, diagnostics, tree, semantic_result, options);
    }

    if (options.no_global_assign) {
        try no_global_assign.runWithOptions(allocator, diagnostics, tree, semantic_result.symbol_table, .{
            .exceptions = options.no_global_assign_exceptions,
        });
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
        try no_invalid_regexp.runWithOptions(allocator, diagnostics, tree, .{
            .allow_constructor_flags = options.no_invalid_regexp_allow_constructor_flags,
        });
    }

    if (options.no_regex_spaces) {
        try no_regex_spaces.run(allocator, diagnostics, tree, semantic_result.symbol_table);
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
            options.prefer_promise_reject_errors_allow_empty_reject,
        );
    }

    if (options.prefer_exponentiation_operator) {
        try prefer_exponentiation_operator.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.prefer_regex_literals) {
        try prefer_regex_literals.runWithOptions(allocator, diagnostics, tree, semantic_result.symbol_table, .{
            .disallow_redundant_wrapping = options.prefer_regex_literals_disallow_redundant_wrapping,
        });
    }

    if (options.prefer_numeric_literals) {
        try prefer_numeric_literals.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.prefer_object_has_own) {
        try prefer_object_has_own.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.prefer_object_spread) {
        try prefer_object_spread.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.radix) {
        try radix.runWithOptions(allocator, diagnostics, tree, semantic_result.symbol_table, .{
            .style = switch (options.radix_style) {
                .always => .always,
                .as_needed => .as_needed,
            },
        });
    }

    if (options.require_atomic_updates) {
        try require_atomic_updates.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_unused_vars and !options.typescript_eslint_no_unused_vars) {
        try no_unused_vars.runWithOptions(allocator, diagnostics, tree, semantic_result.scope_tree, semantic_result.symbol_table, .{
            .vars = options.no_unused_vars_vars,
            .check_parameters = options.no_unused_vars_args != .none,
            .args_after_used = options.no_unused_vars_args == .after_used,
            .check_caught_errors = options.no_unused_vars_caught_errors == .all,
            .ignore_rest_siblings = options.no_unused_vars_ignore_rest_siblings,
            .react_jsx_uses_react = options.react_jsx_uses_react,
            .react_jsx_uses_vars = options.react_jsx_uses_vars,
        });
    }

    if (options.typescript_eslint_no_unused_vars) {
        try typescript_eslint_no_unused_vars.run(
            allocator,
            diagnostics,
            tree,
            semantic_result.scope_tree,
            semantic_result.symbol_table,
            options.react_jsx_uses_react,
            options.react_jsx_uses_vars,
            options.typescript_eslint_no_unused_vars_vars,
            options.typescript_eslint_no_unused_vars_args,
            options.typescript_eslint_no_unused_vars_caught_errors,
            options.typescript_eslint_no_unused_vars_ignore_rest_siblings,
        );
    }

    if (options.no_use_before_define and !options.typescript_eslint_no_use_before_define) {
        try no_use_before_define.runWithOptions(allocator, diagnostics, tree, semantic_result.scope_tree, semantic_result.symbol_table, .{
            .check_functions = options.no_use_before_define_check_functions == .yes,
            .check_classes = options.no_use_before_define_check_classes == .yes,
            .check_variables = options.no_use_before_define_check_variables == .yes,
            .allow_named_exports = options.no_use_before_define_allow_named_exports,
        });
    }

    if (options.typescript_eslint_no_use_before_define) {
        try typescript_eslint_no_use_before_define.runWithOptions(allocator, diagnostics, tree, semantic_result.scope_tree, semantic_result.symbol_table, .{
            .check_functions = options.typescript_eslint_no_use_before_define_check_functions == .yes,
            .check_classes = options.typescript_eslint_no_use_before_define_check_classes == .yes,
            .check_variables = options.typescript_eslint_no_use_before_define_check_variables == .yes,
            .allow_named_exports = options.typescript_eslint_no_use_before_define_allow_named_exports,
        });
    }

    if (options.no_undef) {
        try no_undef.runWithOptions(allocator, diagnostics, tree, semantic_result.symbol_table, .{
            .check_typeof = options.no_undef_typeof,
        });
    }

    if (options.react_jsx_no_undef) {
        try react_jsx_no_undef.run(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.prefer_const) {
        try prefer_const.runWithOptions(allocator, diagnostics, tree, semantic_result.symbol_table, .{
            .destructuring = switch (options.prefer_const_destructuring) {
                .any => .any,
                .all => .all,
            },
        });
    }
}

const BasicVisitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    file_path: []const u8,
    options: core.Options,
    react_button_has_type_state: react_button_has_type.State = .{},
    react_default_props_match_prop_types_state: react_default_props_match_prop_types.State = .{},
    react_display_name_state: react_display_name.State = .{},
    react_require_render_return_state: react_require_render_return.State = .{},
    react_no_danger_with_children_bindings: react_no_danger_with_children.ObjectBindings = .{},
    react_no_access_state_in_setstate_state: react_no_access_state_in_setstate.State = .{},
    react_forbid_prop_types_state: react_forbid_prop_types.State = .{},
    react_no_children_prop_bindings: react_no_children_prop.ReactBindings = .{},
    react_no_array_index_key_state: react_no_array_index_key.State = .{},
    react_jsx_filename_extension_state: react_jsx_filename_extension.State = .{},
    react_jsx_no_bind_state: react_jsx_no_bind.State = .{},
    react_jsx_key_state: react_jsx_key.State = .{},
    react_no_multi_comp_state: react_no_multi_comp.State = .{},
    react_no_typos_state: react_no_typos.State = .{},
    react_no_unused_state_state: react_no_unused_state.State = .{},
    react_style_prop_object_bindings: react_style_prop_object.Bindings = .{},
    react_void_dom_elements_no_children_bindings: react_void_dom_elements_no_children.ReactBindings = .{},

    fn curlyOptions(self: *const BasicVisitor) curly.Options {
        return .{
            .style = self.options.curly_style,
        };
    }

    fn noLabelsOptions(self: *const BasicVisitor) no_labels.Options {
        return .{
            .allow_loop = self.options.no_labels_allow_loop == .yes,
            .allow_switch = self.options.no_labels_allow_switch == .yes,
        };
    }

    fn noUselessRenameOptions(self: *const BasicVisitor) no_useless_rename.Options {
        return .{
            .ignore_destructuring = self.options.no_useless_rename_ignore_destructuring,
            .ignore_import = self.options.no_useless_rename_ignore_import,
            .ignore_export = self.options.no_useless_rename_ignore_export,
        };
    }

    fn noBitwiseOptions(self: *const BasicVisitor) no_bitwise.Options {
        return .{
            .allow_bitwise_and = self.options.no_bitwise_allow_bitwise_and,
            .allow_bitwise_or = self.options.no_bitwise_allow_bitwise_or,
            .allow_bitwise_xor = self.options.no_bitwise_allow_bitwise_xor,
            .allow_bitwise_not = self.options.no_bitwise_allow_bitwise_not,
            .allow_left_shift = self.options.no_bitwise_allow_left_shift,
            .allow_right_shift = self.options.no_bitwise_allow_right_shift,
            .allow_unsigned_right_shift = self.options.no_bitwise_allow_unsigned_right_shift,
            .int32_hint = self.options.no_bitwise_int32_hint,
        };
    }

    fn useIsnanOptions(self: *const BasicVisitor) use_isnan.Options {
        return .{
            .enforce_for_index_of = self.options.use_isnan_enforce_for_index_of,
            .enforce_for_switch_case = self.options.use_isnan_enforce_for_switch_case,
        };
    }

    fn funcNamesStyle(self: *const BasicVisitor, function: ast.Function) func_names.Style {
        const style = if (function.generator and self.options.func_names_has_generator_style)
            self.options.func_names_generator_style
        else
            self.options.func_names_style;

        return switch (style) {
            .always => .always,
            .as_needed => .as_needed,
            .never => .never,
        };
    }

    pub fn enter_node(
        self: *BasicVisitor,
        data: ast.NodeData,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.alipay_ant_no_negative_conditionals) {
            try alipay_ant_no_negative_conditionals.checkNode(self.allocator, self.diagnostics, ctx.tree, data, index);
        }
        if (self.options.no_undefined) {
            switch (data) {
                .identifier_reference => |identifier| try no_undefined.checkIdentifierReference(self.allocator, self.diagnostics, ctx.tree, identifier, index),
                .binding_identifier => |identifier| try no_undefined.checkBindingIdentifier(self.allocator, self.diagnostics, ctx.tree, identifier, index),
                else => {},
            }
        }
        return .proceed;
    }

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
            try import_newline_after_import.check(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                program,
                self.options.import_newline_after_import_count,
                self.options.import_newline_after_import_exact_count,
            );
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
        if (self.options.react_no_deprecated) {
            try react_no_deprecated.checkProgram(self.allocator, self.diagnostics, ctx.tree, program);
        }
        if (self.options.react_no_typos) {
            try react_no_typos.collectProgram(self.allocator, self.diagnostics, ctx.tree, program, &self.react_no_typos_state);
        }
        if (self.options.react_forbid_prop_types) {
            try react_forbid_prop_types.collectProgram(self.allocator, ctx.tree, program, &self.react_forbid_prop_types_state);
        }
        if (self.options.react_no_children_prop) {
            self.react_no_children_prop_bindings = react_no_children_prop.bindingsFromProgram(ctx.tree, program);
        }
        if (self.options.react_button_has_type) {
            react_button_has_type.collectProgram(ctx.tree, program, &self.react_button_has_type_state);
        }
        if (self.options.react_default_props_match_prop_types) {
            try react_default_props_match_prop_types.collectProgram(self.allocator, ctx.tree, program, &self.react_default_props_match_prop_types_state);
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
            try no_duplicate_imports.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, program, .{
                .allow_separate_type_imports = self.options.no_duplicate_imports_allow_separate_type_imports,
            });
        }
        if (self.options.typescript_eslint_adjacent_overload_signatures) {
            try typescript_eslint_adjacent_overload_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, program.body);
        }
        if (self.options.typescript_eslint_unified_signatures) {
            try typescript_eslint_unified_signatures.checkRange(self.allocator, self.diagnostics, ctx.tree, program.body);
        }
        if (self.options.typescript_eslint_no_useless_empty_export) {
            try typescript_eslint_no_useless_empty_export.check(self.allocator, self.diagnostics, ctx.tree, program);
        }
        return .proceed;
    }

    pub fn exit_program(
        self: *BasicVisitor,
        _: ast.Program,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        if (self.options.react_display_name) {
            react_display_name.finish(self.allocator, self.diagnostics, ctx.tree, &self.react_display_name_state) catch {};
        }
        if (self.options.react_default_props_match_prop_types) {
            react_default_props_match_prop_types.finish(self.allocator, self.diagnostics, ctx.tree, &self.react_default_props_match_prop_types_state, .{
                .allow_required_defaults = self.options.react_default_props_match_prop_types_allow_required_defaults,
            }) catch {};
        }
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
        if (self.options.no_underscore_dangle) {
            try no_underscore_dangle.checkFunctionWithOptions(self.allocator, self.diagnostics, ctx.tree, function, .{
                .allow = self.options.no_underscore_dangle_allow,
                .allow_function_params = self.options.no_underscore_dangle_allow_function_params == .yes,
            });
        }
        if (self.options.consistent_return) {
            try consistent_return.checkFunctionWithOptions(self.allocator, self.diagnostics, ctx.tree, function, .{
                .treat_undefined_as_unspecified = self.options.consistent_return_treat_undefined_as_unspecified,
            });
        }
        if (self.options.func_names) {
            try func_names.checkWithStyle(self.allocator, self.diagnostics, ctx.tree, function, index, ctx, self.funcNamesStyle(function));
        }
        if (self.options.default_param_last) {
            try default_param_last.check(self.allocator, self.diagnostics, ctx.tree, function.params);
        }
        if (self.options.typescript_eslint_typedef and self.options.typescript_eslint_typedef_parameter) {
            try typescript_eslint_typedef.checkFunctionParameters(self.allocator, self.diagnostics, ctx.tree, function);
        }
        if (self.options.no_param_reassign) {
            try no_param_reassign.checkFunctionWithOptions(self.allocator, self.diagnostics, ctx.tree, function, .{
                .props = self.options.no_param_reassign_props == .yes,
                .ignore_property_modifications_for = self.options.no_param_reassign_ignore_property_modifications_for,
            });
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
        if (self.options.react_display_name) {
            try react_display_name.checkFunction(self.allocator, ctx.tree, function, index, ctx.path.parent(), &self.react_display_name_state, reactDisplayNameOptions(self.options));
        }
        if (self.options.react_no_multi_comp) {
            try react_no_multi_comp.checkFunction(self.allocator, self.diagnostics, ctx.tree, function, index, &self.react_no_multi_comp_state, .{
                .ignore_stateless = self.options.react_no_multi_comp_ignore_stateless,
            });
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
        if (self.options.no_underscore_dangle) {
            try no_underscore_dangle.checkClassWithOptions(self.allocator, self.diagnostics, ctx.tree, class, .{
                .allow = self.options.no_underscore_dangle_allow,
            });
        }
        if (self.options.react_require_render_return) {
            try react_require_render_return.checkClass(self.allocator, self.diagnostics, ctx.tree, class, self.react_require_render_return_state);
        }
        if (self.options.react_display_name) {
            try react_display_name.checkClass(self.allocator, ctx.tree, class, index, ctx.path.parent(), &self.react_display_name_state, reactDisplayNameOptions(self.options));
        }
        if (self.options.react_no_multi_comp) {
            try react_no_multi_comp.checkClass(self.allocator, self.diagnostics, ctx.tree, class, index, &self.react_no_multi_comp_state);
        }
        if (self.options.react_prefer_es6_class) {
            try react_prefer_es6_class.checkClass(self.allocator, self.diagnostics, ctx.tree, class, index, reactPreferEs6ClassStyle(self.options.react_prefer_es6_class_style));
        }
        if (self.options.react_no_redundant_should_component_update) {
            try react_no_redundant_should_component_update.checkClass(self.allocator, self.diagnostics, ctx.tree, class, index, ctx.path.parent());
        }
        if (self.options.react_no_unused_state) {
            try react_no_unused_state.enterClass(self.allocator, ctx.tree, class, index, &self.react_no_unused_state_state);
        }
        if (self.options.react_no_deprecated) {
            try react_no_deprecated.checkClass(self.allocator, self.diagnostics, ctx.tree, class);
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
        if (self.options.typescript_eslint_no_unnecessary_parameter_property_assignment) {
            try typescript_eslint_no_unnecessary_parameter_property_assignment.checkClass(self.allocator, self.diagnostics, ctx.tree, class);
        }
        return .proceed;
    }

    pub fn exit_class(
        self: *BasicVisitor,
        _: ast.Class,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        if (self.options.react_no_unused_state) {
            react_no_unused_state.exitClass(self.allocator, self.diagnostics, ctx.tree, index, &self.react_no_unused_state_state) catch {};
        }
    }

    pub fn enter_if_statement(
        self: *BasicVisitor,
        statement: ast.IfStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.curly) {
            try curly.checkIfStatementWithOptions(self.allocator, self.diagnostics, ctx.tree, statement, self.curlyOptions());
        }
        if (self.options.no_cond_assign) {
            try no_cond_assign.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, statement.@"test", .{
                .style = self.options.no_cond_assign_style,
            });
        }
        if (self.options.no_constant_condition) {
            try no_constant_condition.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test");
        }
        if (self.options.no_else_return) {
            try no_else_return.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, statement, .{
                .allow_else_if = self.options.no_else_return_allow_else_if,
            });
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
        if (self.options.logical_assignment_operators and
            self.options.logical_assignment_operators_style == .always and
            self.options.logical_assignment_operators_enforce_for_if_statements == .yes)
        {
            try logical_assignment_operators.checkIfStatement(self.allocator, self.diagnostics, ctx.tree, statement, index);
        }
        if (self.options.alipay_ant_prefer_elseif_end_with_else) {
            try alipay_ant_prefer_elseif_end_with_else.check(self.allocator, self.diagnostics, ctx.tree, statement, index, ctx);
        }
        return .proceed;
    }

    pub fn enter_import_declaration(
        self: *BasicVisitor,
        declaration: ast.ImportDeclaration,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.alipay_ant_prefer_import_as_required) {
            try alipay_ant_prefer_import_as_required.checkImportDeclaration(self.allocator, self.diagnostics, ctx.tree, declaration, index);
        }
        if (self.options.alipay_ant_no_deprecated_dependence) {
            try alipay_ant_no_deprecated_dependence.checkImportDeclaration(self.allocator, self.diagnostics, ctx.tree, declaration, index, self.options.alipay_ant_no_deprecated_dependence_profile);
        }
        if (self.options.alipay_ant_no_import_files_from_pages_in_common) {
            try alipay_ant_no_import_files_from_pages_in_common.checkImportDeclaration(self.allocator, self.diagnostics, ctx.tree, declaration, index, self.file_path);
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
            try curly.checkBodyWithOptions(self.allocator, self.diagnostics, ctx.tree, statement.body, self.curlyOptions());
        }
        if (self.options.no_cond_assign) {
            try no_cond_assign.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, statement.@"test", .{
                .style = self.options.no_cond_assign_style,
            });
        }
        if (self.options.no_constant_condition) {
            switch (self.options.no_constant_condition_check_loops) {
                .all => try no_constant_condition.check(self.allocator, self.diagnostics, ctx.tree, statement.@"test"),
                .all_except_while_true => try no_constant_condition.checkWhile(self.allocator, self.diagnostics, ctx.tree, statement.@"test"),
                .none => {},
            }
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
            try curly.checkBodyWithOptions(self.allocator, self.diagnostics, ctx.tree, statement.body, self.curlyOptions());
        }
        if (self.options.no_cond_assign) {
            try no_cond_assign.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, statement.@"test", .{
                .style = self.options.no_cond_assign_style,
            });
        }
        if (self.options.no_constant_condition and self.options.no_constant_condition_check_loops != .none) {
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
            try curly.checkBodyWithOptions(self.allocator, self.diagnostics, ctx.tree, statement.body, self.curlyOptions());
        }
        if (self.options.no_cond_assign and statement.@"test" != .null) {
            try no_cond_assign.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, statement.@"test", .{
                .style = self.options.no_cond_assign_style,
            });
        }
        if (self.options.no_constant_condition and
            self.options.no_constant_condition_check_loops != .none and
            statement.@"test" != .null)
        {
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
            try no_unneeded_ternary.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .default_assignment = self.options.no_unneeded_ternary_default_assignment,
            });
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
            try no_unused_expressions.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, statement, index, .{
                .allow_short_circuit = self.options.no_unused_expressions_allow_short_circuit == .yes,
                .allow_ternary = self.options.no_unused_expressions_allow_ternary == .yes,
                .allow_tagged_templates = self.options.no_unused_expressions_allow_tagged_templates == .yes,
            });
        }
        if (self.options.typescript_eslint_no_unused_expressions) {
            try typescript_eslint_no_unused_expressions.check(self.allocator, self.diagnostics, ctx.tree, statement, index, .{
                .allow_short_circuit = self.options.typescript_eslint_no_unused_expressions_allow_short_circuit == .yes,
                .allow_ternary = self.options.typescript_eslint_no_unused_expressions_allow_ternary == .yes,
                .allow_tagged_templates = self.options.typescript_eslint_no_unused_expressions_allow_tagged_templates == .yes,
            });
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
            try typescript_eslint_consistent_type_assertions.checkAsExpression(self.allocator, self.diagnostics, ctx.tree, expression, index, ctx, .{
                .assertion_style = self.options.typescript_eslint_consistent_type_assertions_assertion_style,
                .object_literal_type_assertions = self.options.typescript_eslint_consistent_type_assertions_object_literal_type_assertions,
                .array_literal_type_assertions = self.options.typescript_eslint_consistent_type_assertions_array_literal_type_assertions,
            });
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
            try typescript_eslint_consistent_type_assertions.checkTypeAssertion(self.allocator, self.diagnostics, ctx.tree, assertion, index, ctx, .{
                .assertion_style = self.options.typescript_eslint_consistent_type_assertions_assertion_style,
                .object_literal_type_assertions = self.options.typescript_eslint_consistent_type_assertions_object_literal_type_assertions,
                .array_literal_type_assertions = self.options.typescript_eslint_consistent_type_assertions_array_literal_type_assertions,
            });
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
            try typescript_eslint_array_type.checkArrayType(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                array_type,
                index,
                self.options.typescript_eslint_array_type_style,
            );
        }
        return .proceed;
    }

    pub fn enter_variable_declarator(
        self: *BasicVisitor,
        declarator: ast.VariableDeclarator,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_prefer_as_const) {
            try typescript_eslint_prefer_as_const.checkVariableDeclarator(self.allocator, self.diagnostics, ctx.tree, declarator);
        }
        if (self.options.typescript_eslint_no_this_alias) {
            try typescript_eslint_no_this_alias.checkVariableDeclarator(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                declarator,
                &self.options.typescript_eslint_no_this_alias_allowed_names,
            );
        }
        if (self.options.typescript_eslint_no_inferrable_types) {
            try typescript_eslint_no_inferrable_types.checkVariableDeclarator(self.allocator, self.diagnostics, ctx.tree, declarator);
        }
        if (self.options.no_underscore_dangle) {
            try no_underscore_dangle.checkVariableDeclaratorWithOptions(self.allocator, self.diagnostics, ctx.tree, declarator, .{
                .allow = self.options.no_underscore_dangle_allow,
                .allow_in_array_destructuring = self.options.no_underscore_dangle_allow_in_array_destructuring == .yes,
                .allow_in_object_destructuring = self.options.no_underscore_dangle_allow_in_object_destructuring == .yes,
            });
        }
        if (self.options.no_multi_assign) {
            try no_multi_assign.checkVariableDeclarator(self.allocator, self.diagnostics, ctx.tree, declarator);
        }
        if (self.options.func_name_matching) {
            try func_name_matching.checkVariableDeclaratorWithOptions(self.allocator, self.diagnostics, ctx.tree, declarator, .{
                .style = funcNameMatchingStyle(self.options.func_name_matching_style),
            });
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
        if (self.options.react_display_name) {
            try react_display_name.checkVariableDeclarator(self.allocator, ctx.tree, declarator, index, &self.react_display_name_state, .{
                .check_context_objects = self.options.react_display_name_check_context_objects,
                .ignore_transpiler_name = self.options.react_display_name_ignore_transpiler_name,
            });
        }
        if (self.options.react_no_deprecated) {
            try react_no_deprecated.checkVariableDeclarator(self.allocator, self.diagnostics, ctx.tree, declarator);
        }
        if (self.options.react_no_multi_comp) {
            try react_no_multi_comp.checkVariableDeclarator(self.allocator, self.diagnostics, ctx.tree, declarator, index, &self.react_no_multi_comp_state, .{
                .ignore_stateless = self.options.react_no_multi_comp_ignore_stateless,
            });
        }
        if (self.options.react_no_access_state_in_setstate) {
            try react_no_access_state_in_setstate.checkVariableDeclarator(
                self.allocator,
                ctx.tree,
                declarator,
                index,
                ctx,
                &self.react_no_access_state_in_setstate_state,
            );
        }
        if (self.options.react_forbid_prop_types) {
            try react_forbid_prop_types.collectVariableDeclarator(self.allocator, ctx.tree, declarator, &self.react_forbid_prop_types_state);
        }
        if (self.options.react_no_unused_state) {
            try react_no_unused_state.checkVariableDeclarator(self.allocator, ctx.tree, declarator, &self.react_no_unused_state_state);
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
            try typescript_eslint_no_inferrable_types.checkAssignmentPattern(self.allocator, self.diagnostics, ctx.tree, pattern, .{
                .ignore_parameters = self.options.typescript_eslint_no_inferrable_types_ignore_parameters,
                .ignore_properties = self.options.typescript_eslint_no_inferrable_types_ignore_properties,
            });
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
            try typescript_eslint_no_empty_interface.check(self.allocator, self.diagnostics, ctx.tree, interface_declaration, .{
                .allow_single_extends = self.options.typescript_eslint_no_empty_interface_allow_single_extends,
            });
        }
        if (self.options.typescript_eslint_no_misused_new) {
            try typescript_eslint_no_misused_new.checkInterfaceDeclaration(self.allocator, self.diagnostics, ctx.tree, interface_declaration);
        }
        if (self.options.typescript_eslint_consistent_type_definitions) {
            try typescript_eslint_consistent_type_definitions.checkInterfaceDeclaration(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                interface_declaration,
                self.options.typescript_eslint_consistent_type_definitions_style,
            );
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
            try typescript_eslint_consistent_type_definitions.checkTypeAliasDeclaration(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                declaration,
                self.options.typescript_eslint_consistent_type_definitions_style,
            );
        }
        _ = index;
        return .proceed;
    }

    pub fn enter_ts_enum_declaration(
        self: *BasicVisitor,
        declaration: ast.TSEnumDeclaration,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_no_duplicate_enum_values) {
            try typescript_eslint_no_duplicate_enum_values.check(self.allocator, self.diagnostics, ctx.tree, declaration);
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
            try typescript_eslint_method_signature_style.checkMethodSignature(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                signature,
                index,
                self.options.typescript_eslint_method_signature_style_style,
            );
        }
        return .proceed;
    }

    pub fn enter_ts_type_literal(
        self: *BasicVisitor,
        type_literal: ast.TSTypeLiteral,
        index: ast.NodeIndex,
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
        if (self.options.typescript_eslint_ban_types) {
            try typescript_eslint_ban_types.checkTypeLiteral(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                type_literal,
                index,
                self.options.typescript_eslint_ban_types_config,
            );
        }
        return .proceed;
    }

    pub fn enter_ts_property_signature(
        self: *BasicVisitor,
        signature: ast.TSPropertySignature,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_typedef and self.options.typescript_eslint_typedef_property_declaration) {
            try typescript_eslint_typedef.checkPropertySignature(self.allocator, self.diagnostics, ctx.tree, signature, index);
        }
        if (self.options.typescript_eslint_method_signature_style) {
            try typescript_eslint_method_signature_style.checkPropertySignature(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                signature,
                index,
                self.options.typescript_eslint_method_signature_style_style,
            );
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
            try typescript_eslint_array_type.checkTypeReference(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                reference,
                index,
                self.options.typescript_eslint_array_type_style,
            );
        }
        const wrapper_object_type_reported =
            self.options.typescript_eslint_no_wrapper_object_types and
            typescript_eslint_no_wrapper_object_types.isWrapperObjectTypeReference(ctx.tree, reference);
        if (self.options.typescript_eslint_ban_types and !wrapper_object_type_reported) {
            try typescript_eslint_ban_types.checkTypeReference(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                reference,
                self.options.typescript_eslint_ban_types_config,
            );
        }
        if (self.options.typescript_eslint_no_wrapper_object_types) {
            try typescript_eslint_no_wrapper_object_types.checkTypeReference(self.allocator, self.diagnostics, ctx.tree, reference);
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

    pub fn enter_ts_object_keyword(
        self: *BasicVisitor,
        _: ast.TSObjectKeyword,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.typescript_eslint_ban_types) {
            try typescript_eslint_ban_types.checkObjectKeyword(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                index,
                self.options.typescript_eslint_ban_types_config,
            );
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
            try typescript_eslint_no_namespace.check(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                declaration,
                index,
                self.options.typescript_eslint_no_namespace_allow_declarations,
            );
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
            try default_case.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, statement, index, .{
                .comment_pattern = self.options.default_case_comment_pattern,
            });
        }
        if (self.options.default_case_last) {
            try default_case_last.check(self.allocator, self.diagnostics, ctx.tree, statement);
        }
        if (self.options.no_duplicate_case) {
            try no_duplicate_case.check(self.allocator, self.diagnostics, ctx.tree, statement);
        }
        if (self.options.no_fallthrough) {
            try no_fallthrough.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, statement, .{
                .allow_empty_case = self.options.no_fallthrough_allow_empty_case == .yes,
            });
        }
        if (self.options.use_isnan) {
            try use_isnan.checkSwitchStatementWithOptions(self.allocator, self.diagnostics, ctx.tree, statement, index, self.useIsnanOptions());
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
        if (self.options.use_isnan) {
            try use_isnan.checkSwitchCaseWithOptions(self.allocator, self.diagnostics, ctx.tree, switch_case, self.useIsnanOptions());
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
        if (self.options.no_useless_return) {
            try no_useless_return.check(self.allocator, self.diagnostics, ctx.tree, statement, index, ctx);
        }
        if (self.options.no_return_assign) {
            try no_return_assign.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, statement.argument, .{
                .style = self.options.no_return_assign_style,
            });
        }
        return .proceed;
    }

    pub fn enter_continue_statement(
        self: *BasicVisitor,
        statement: ast.ContinueStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_continue) {
            try no_continue.check(self.allocator, self.diagnostics, ctx.tree, index);
        }
        if (self.options.no_labels) {
            try no_labels.checkContinueStatementWithOptions(self.allocator, self.diagnostics, ctx.tree, statement, index, &ctx.path, self.noLabelsOptions());
        }
        return .proceed;
    }

    pub fn enter_break_statement(
        self: *BasicVisitor,
        statement: ast.BreakStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_labels) {
            try no_labels.checkBreakStatementWithOptions(self.allocator, self.diagnostics, ctx.tree, statement, index, &ctx.path, self.noLabelsOptions());
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
            try no_labels.checkLabeledStatementWithOptions(self.allocator, self.diagnostics, ctx.tree, statement, index, self.noLabelsOptions());
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
            try curly.checkBodyWithOptions(self.allocator, self.diagnostics, ctx.tree, statement.body, self.curlyOptions());
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
            try curly.checkBodyWithOptions(self.allocator, self.diagnostics, ctx.tree, statement.body, self.curlyOptions());
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
            try no_empty.checkBlockStatementWithOptions(self.allocator, self.diagnostics, ctx.tree, block, index, .{
                .allow_empty_catch = self.options.no_empty_allow_empty_catch == .yes,
                .is_catch_body = isCatchBody(ctx.tree, index, ctx.path.parent()),
            });
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
            try no_empty_function.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, body, index, .{
                .allow = self.options.no_empty_function_allow,
                .kind = emptyFunctionKind(ctx.tree, ctx),
            });
        }
        if (self.options.typescript_eslint_no_empty_function) {
            try typescript_eslint_no_empty_function.checkFunctionBodyWithOptions(self.allocator, self.diagnostics, ctx.tree, body, index, ctx, .{
                .allow = self.options.typescript_eslint_no_empty_function_allow,
                .kind = emptyFunctionKind(ctx.tree, ctx),
            });
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
        if (self.options.vars_on_top) {
            try vars_on_top.check(self.allocator, self.diagnostics, ctx.tree, declaration, index, ctx);
        }
        if (self.options.no_undef_init) {
            try no_undef_init.check(self.allocator, self.diagnostics, ctx.tree, declaration);
        }
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkVariableDeclaration(self.allocator, self.diagnostics, ctx.tree, declaration);
        }
        if (self.options.no_inner_declarations) {
            try no_inner_declarations.checkVariableDeclaration(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                declaration,
                index,
                ctx,
                switch (self.options.no_inner_declarations_mode) {
                    .functions => .functions,
                    .both => .both,
                },
            );
        }
        if (self.options.one_var) {
            try one_var.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, declaration, index, ctx, .{
                .check_var = self.options.one_var_check_var,
                .check_let = self.options.one_var_check_let,
                .check_const = self.options.one_var_check_const,
            });
        }
        if (self.options.typescript_eslint_typedef and (self.options.typescript_eslint_typedef_variable_declaration or
            self.options.typescript_eslint_typedef_array_destructuring or
            self.options.typescript_eslint_typedef_object_destructuring))
        {
            try typescript_eslint_typedef.checkVariableDeclaration(self.allocator, self.diagnostics, ctx.tree, declaration, .{
                .variable_declaration = self.options.typescript_eslint_typedef_variable_declaration,
                .array_destructuring = self.options.typescript_eslint_typedef_array_destructuring,
                .object_destructuring = self.options.typescript_eslint_typedef_object_destructuring,
                .ignore_function = self.options.typescript_eslint_typedef_variable_declaration_ignore_function,
            });
        }
        if (self.options.prefer_destructuring) {
            try prefer_destructuring.checkVariableDeclarationWithOptions(self.allocator, self.diagnostics, ctx.tree, declaration, .{
                .variable_declarator_array = self.options.prefer_destructuring_variable_declarator_array,
                .variable_declarator_object = self.options.prefer_destructuring_variable_declarator_object,
                .assignment_expression_array = self.options.prefer_destructuring_assignment_expression_array,
                .assignment_expression_object = self.options.prefer_destructuring_assignment_expression_object,
                .enforce_for_renamed_properties = self.options.prefer_destructuring_enforce_for_renamed_properties,
            });
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
        if (self.options.alipay_ant_disallow_typos) {
            try alipay_ant_disallow_typos.checkStringLiteral(self.allocator, self.diagnostics, ctx.tree, literal, index);
        }
        if (self.options.alipay_ant_prefer_managed_resource) {
            try alipay_ant_prefer_managed_resource.checkStringLiteral(self.allocator, self.diagnostics, ctx.tree, literal, index);
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
            try no_useless_escape.checkTemplateLiteral(self.allocator, self.diagnostics, ctx.tree, literal, ctx.path.parent() orelse .null);
        }
        if (self.options.alipay_ant_disallow_typos) {
            try alipay_ant_disallow_typos.checkTemplateLiteral(self.allocator, self.diagnostics, ctx.tree, literal);
        }
        if (self.options.no_implicit_coercion) {
            try no_implicit_coercion.checkTemplateLiteralWithOptions(self.allocator, self.diagnostics, ctx.tree, literal, index, ctx.path.parent() orelse .null, self.noImplicitCoercionOptions());
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
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_return_assign and expression.expression) {
            try no_return_assign.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression.body, .{
                .style = self.options.no_return_assign_style,
            });
        }
        if (self.options.consistent_return) {
            try consistent_return.checkArrowFunctionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, .{
                .treat_undefined_as_unspecified = self.options.consistent_return_treat_undefined_as_unspecified,
            });
        }
        if (self.options.default_param_last) {
            try default_param_last.check(self.allocator, self.diagnostics, ctx.tree, expression.params);
        }
        if (self.options.typescript_eslint_typedef and self.options.typescript_eslint_typedef_arrow_parameter) {
            try typescript_eslint_typedef.checkArrowFunctionParameters(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        if (self.options.no_underscore_dangle) {
            try no_underscore_dangle.checkFormalParametersWithOptions(self.allocator, self.diagnostics, ctx.tree, expression.params, .{
                .allow = self.options.no_underscore_dangle_allow,
                .allow_function_params = self.options.no_underscore_dangle_allow_function_params == .yes,
            });
        }
        if (self.options.no_confusing_arrow) {
            try no_confusing_arrow.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, .{
                .allow_parens = self.options.no_confusing_arrow_allow_parens == .yes,
            });
        }
        if (self.options.no_shadow_restricted_names) {
            try no_shadow_restricted_names.checkFormalParameters(self.allocator, self.diagnostics, ctx.tree, expression.params);
        }
        if (self.options.no_param_reassign) {
            try no_param_reassign.checkArrowFunctionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, .{
                .props = self.options.no_param_reassign_props == .yes,
                .ignore_property_modifications_for = self.options.no_param_reassign_ignore_property_modifications_for,
            });
        }
        if (self.options.react_display_name) {
            try react_display_name.checkArrowFunction(self.allocator, ctx.tree, index, ctx.path.parent(), &self.react_display_name_state, reactDisplayNameOptions(self.options));
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
            try no_bitwise.checkAssignmentExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, self.noBitwiseOptions());
        }
        if (self.options.no_multi_assign) {
            try no_multi_assign.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .ignore_non_declaration = self.options.no_multi_assign_ignore_non_declaration,
            });
        }
        if (self.options.operator_assignment) {
            try operator_assignment.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .style = self.options.operator_assignment_style,
            });
        }
        if (self.options.logical_assignment_operators) {
            try logical_assignment_operators.checkAssignmentExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .style = switch (self.options.logical_assignment_operators_style) {
                    .always => .always,
                    .never => .never,
                },
            });
        }
        if (self.options.func_name_matching) {
            try func_name_matching.checkAssignmentExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, .{
                .style = funcNameMatchingStyle(self.options.func_name_matching_style),
            });
        }
        if (self.options.prefer_destructuring) {
            try prefer_destructuring.checkAssignmentExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, .{
                .variable_declarator_array = self.options.prefer_destructuring_variable_declarator_array,
                .variable_declarator_object = self.options.prefer_destructuring_variable_declarator_object,
                .assignment_expression_array = self.options.prefer_destructuring_assignment_expression_array,
                .assignment_expression_object = self.options.prefer_destructuring_assignment_expression_object,
                .enforce_for_renamed_properties = self.options.prefer_destructuring_enforce_for_renamed_properties,
            });
        }
        if (self.options.no_useless_rename) {
            try no_useless_rename.checkAssignmentExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, self.noUselessRenameOptions());
        }
        if (self.options.no_self_assign) {
            try no_self_assign.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .props = self.options.no_self_assign_props,
            });
        }
        if (self.options.no_implicit_coercion) {
            try no_implicit_coercion.checkAssignmentExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, self.noImplicitCoercionOptions());
        }
        if (self.options.typescript_eslint_no_confusing_non_null_assertion) {
            try typescript_eslint_no_confusing_non_null_assertion.checkAssignmentExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.typescript_eslint_no_this_alias) {
            try typescript_eslint_no_this_alias.checkAssignmentExpression(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                expression,
                &self.options.typescript_eslint_no_this_alias_allowed_names,
            );
        }
        if (self.options.react_no_typos) {
            try react_no_typos.checkAssignmentExpression(self.allocator, self.diagnostics, ctx.tree, expression, self.react_no_typos_state);
        }
        if (self.options.react_no_unused_state) {
            try react_no_unused_state.checkAssignmentExpression(self.allocator, ctx.tree, expression, ctx, &self.react_no_unused_state_state);
        }
        if (self.options.react_forbid_prop_types) {
            try react_forbid_prop_types.checkAssignmentExpression(self.allocator, self.diagnostics, ctx.tree, expression, self.react_forbid_prop_types_state, .{
                .forbid_any = self.options.react_forbid_prop_types_forbid_any,
                .forbid_array = self.options.react_forbid_prop_types_forbid_array,
                .forbid_object = self.options.react_forbid_prop_types_forbid_object,
            });
        }
        return .proceed;
    }

    pub fn enter_logical_expression(
        self: *BasicVisitor,
        expression: ast.LogicalExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.logical_assignment_operators and self.options.logical_assignment_operators_style == .always) {
            try logical_assignment_operators.checkLogicalExpression(self.allocator, self.diagnostics, ctx.tree, expression, index);
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
            try no_bitwise.checkBinaryExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, self.noBitwiseOptions());
        }
        if (self.options.typescript_eslint_restrict_plus_operands) {
            try typescript_eslint_restrict_plus_operands.checkBinaryExpression(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .allow_number_and_string = self.options.typescript_eslint_restrict_plus_operands_allow_number_and_string,
            });
        }
        if (self.options.no_compare_neg_zero) {
            try no_compare_neg_zero.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.eqeqeq) {
            try eqeqeq.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .style = self.options.eqeqeq_style,
            });
        }
        if (self.options.no_eq_null) {
            try no_eq_null.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_self_compare) {
            try no_self_compare.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_unsafe_negation) {
            try no_unsafe_negation.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .enforce_for_ordering_relations = self.options.no_unsafe_negation_enforce_for_ordering_relations,
            });
        }
        if (self.options.use_isnan) {
            try use_isnan.checkBinaryExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, self.useIsnanOptions());
        }
        if (self.options.valid_typeof) {
            try valid_typeof.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .require_string_literals = self.options.valid_typeof_require_string_literals,
            });
        }
        if (self.options.no_useless_concat) {
            try no_useless_concat.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.prefer_template) {
            try prefer_template.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_implicit_coercion) {
            try no_implicit_coercion.checkBinaryExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, self.noImplicitCoercionOptions());
        }
        if (self.options.no_path_concat) {
            try no_path_concat.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.yoda) {
            try yoda.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .style = switch (self.options.yoda_style) {
                    .never => .never,
                    .always => .always,
                },
                .only_equality = self.options.yoda_only_equality,
                .except_range = self.options.yoda_except_range,
                .parent = ctx.path.parent() orelse .null,
            });
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
            try no_bitwise.checkUnaryExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, self.noBitwiseOptions());
        }
        if (self.options.no_delete_var) {
            try no_delete_var.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.no_void) {
            try no_void.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, &ctx.path, .{
                .allow_as_statement = self.options.no_void_allow_as_statement == .yes,
            });
        }
        if (self.options.no_implicit_coercion) {
            try no_implicit_coercion.checkUnaryExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, self.noImplicitCoercionOptions());
        }
        return .proceed;
    }

    fn noImplicitCoercionOptions(self: *BasicVisitor) no_implicit_coercion.Options {
        return .{
            .boolean = self.options.no_implicit_coercion_boolean == .yes,
            .number = self.options.no_implicit_coercion_number == .yes,
            .string = self.options.no_implicit_coercion_string == .yes,
            .allow_double_negation = self.options.no_implicit_coercion_allow_double_negation,
            .allow_bitwise_not = self.options.no_implicit_coercion_allow_bitwise_not,
            .allow_plus = self.options.no_implicit_coercion_allow_plus,
            .allow_multiply = self.options.no_implicit_coercion_allow_multiply,
            .allow_subtract = self.options.no_implicit_coercion_allow_subtract,
            .allow_double_negative = self.options.no_implicit_coercion_allow_double_negative,
            .disallow_template_shorthand = self.options.no_implicit_coercion_disallow_template_shorthand,
        };
    }

    pub fn enter_update_expression(
        self: *BasicVisitor,
        _: ast.UpdateExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_plusplus) {
            try no_plusplus.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, index, ctx, .{
                .allow_for_loop_afterthoughts = self.options.no_plusplus_allow_for_loop_afterthoughts == .yes,
            });
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
            try no_sequences.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, index, ctx, .{
                .allow_in_parentheses = self.options.no_sequences_allow_in_parentheses,
            });
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
            try array_callback_return.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, call, .{
                .allow_implicit = self.options.array_callback_return_allow_implicit == .yes,
                .check_for_each = self.options.array_callback_return_check_for_each == .yes,
                .allow_void = self.options.array_callback_return_allow_void == .yes,
            });
        }
        if (self.options.accessor_pairs) {
            try accessor_pairs.checkCallExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, call, .{
                .get_without_set = self.options.accessor_pairs_get_without_set == .yes,
                .set_without_get = self.options.accessor_pairs_set_without_get == .yes,
            });
        }
        if (self.options.import_no_amd) {
            try import_no_amd.check(self.allocator, self.diagnostics, ctx.tree, call, index);
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
        if (self.options.use_isnan) {
            try use_isnan.checkCallExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, call, self.useIsnanOptions());
        }
        if (self.options.alipay_spmlint_use_labeled_spm) {
            try alipay_spmlint_use_labeled_spm.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index);
        }
        if (self.options.alipay_spmlint_valid_manual_click) {
            try alipay_spmlint_valid_manual_click.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call);
        }
        if (self.options.alipay_spmlint_valid_manual_expo) {
            try alipay_spmlint_valid_manual_expo.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call);
        }
        if (self.options.alipay_spmlint_valid_manual_param) {
            try alipay_spmlint_valid_manual_param.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call);
        }
        if (self.options.alipay_spmlint_valid_manual_pv) {
            try alipay_spmlint_valid_manual_pv.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call);
        }
        if (self.options.alipay_ant_prefer_catch_unsafe_func_call) {
            try alipay_ant_prefer_catch_unsafe_func_call.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index, ctx);
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
        if (self.options.react_no_access_state_in_setstate) {
            try react_no_access_state_in_setstate.checkCallExpression(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                call,
                index,
                ctx,
                &self.react_no_access_state_in_setstate_state,
            );
        }
        if (self.options.react_no_unused_state) {
            try react_no_unused_state.checkCallExpression(self.allocator, ctx.tree, call, &self.react_no_unused_state_state);
        }
        if (self.options.react_display_name) {
            try react_display_name.checkCallExpression(self.allocator, ctx.tree, call, index, ctx.path.parent(), &self.react_display_name_state, reactDisplayNameOptions(self.options));
        }
        if (self.options.react_button_has_type) {
            try react_button_has_type.checkCallExpression(self.allocator, self.diagnostics, ctx.tree, call, index, self.react_button_has_type_state, .{
                .allow_button = self.options.react_button_has_type_button,
                .allow_submit = self.options.react_button_has_type_submit,
                .allow_reset = self.options.react_button_has_type_reset,
            });
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
            try react_jsx_key.enterCallExpression(self.allocator, self.diagnostics, ctx.tree, call, &self.react_jsx_key_state, .{
                .check_key_must_before_spread = self.options.react_jsx_key_check_key_must_before_spread,
                .check_fragment_shorthand = self.options.react_jsx_key_check_fragment_shorthand,
            });
        }
        if (self.options.new_cap) {
            try new_cap.checkCallExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, call, index, .{
                .new_is_cap = self.options.new_cap_new_is_cap,
                .cap_is_new = self.options.new_cap_cap_is_new,
                .properties = self.options.new_cap_properties,
                .new_is_cap_exceptions = self.options.new_cap_new_is_cap_exceptions,
                .cap_is_new_exceptions = self.options.new_cap_cap_is_new_exceptions,
            });
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
            try no_new.check(self.allocator, self.diagnostics, ctx.tree, index, &ctx.path);
        }
        if (self.options.no_new_require) {
            try no_new_require.check(self.allocator, self.diagnostics, ctx.tree, expression, index);
        }
        if (self.options.new_cap) {
            try new_cap.checkNewExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, index, .{
                .new_is_cap = self.options.new_cap_new_is_cap,
                .cap_is_new = self.options.new_cap_cap_is_new,
                .properties = self.options.new_cap_properties,
                .new_is_cap_exceptions = self.options.new_cap_new_is_cap_exceptions,
                .cap_is_new_exceptions = self.options.new_cap_cap_is_new_exceptions,
            });
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
        expression: ast.AwaitExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_return_await) {
            try no_return_await.check(self.allocator, self.diagnostics, ctx.tree, expression, index, ctx);
        }
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
            try dot_notation.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, member, index, .{
                .allow_keywords = self.options.dot_notation_allow_keywords == .yes,
                .allow_pattern = self.options.dot_notation_allow_pattern,
            });
        }
        if (self.options.typescript_eslint_dot_notation) {
            try typescript_eslint_dot_notation.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, member, index, .{
                .allow_keywords = self.options.dot_notation_allow_keywords == .yes,
                .allow_pattern = self.options.dot_notation_allow_pattern,
            });
        }
        if (self.options.no_caller) {
            try no_caller.check(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
        if (self.options.no_proto) {
            try no_proto.check(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
        if (self.options.no_underscore_dangle) {
            try no_underscore_dangle.checkMemberExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, member, .{
                .allow = self.options.no_underscore_dangle_allow,
                .allow_after_this = self.options.no_underscore_dangle_allow_after_this,
                .allow_after_super = self.options.no_underscore_dangle_allow_after_super,
                .allow_after_this_constructor = self.options.no_underscore_dangle_allow_after_this_constructor,
            });
        }
        if (self.options.no_iterator) {
            try no_iterator.check(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
        if (self.options.no_process_env) {
            try no_process_env.check(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
        if (self.options.alipay_ant_no_deprecated_variable) {
            try alipay_ant_no_deprecated_variable.checkMemberExpression(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
        if (self.options.react_no_deprecated) {
            try react_no_deprecated.checkMemberExpression(self.allocator, self.diagnostics, ctx.tree, member, index);
        }
        if (self.options.react_no_access_state_in_setstate) {
            try react_no_access_state_in_setstate.checkMemberExpression(
                self.allocator,
                ctx.tree,
                member,
                index,
                ctx,
                &self.react_no_access_state_in_setstate_state,
            );
        }
        if (self.options.react_no_this_in_sfc) {
            try react_no_this_in_sfc.check(self.allocator, self.diagnostics, ctx.tree, member, index, ctx);
        }
        if (self.options.react_no_unused_state) {
            try react_no_unused_state.checkMemberExpression(self.allocator, ctx.tree, member, index, ctx, &self.react_no_unused_state_state);
        }
        if (self.options.react_display_name) {
            try react_display_name.checkMemberExpression(self.allocator, ctx.tree, member, &self.react_display_name_state);
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
            try react_jsx_key.checkArrayExpression(self.allocator, self.diagnostics, ctx.tree, expression, .{
                .check_key_must_before_spread = self.options.react_jsx_key_check_key_must_before_spread,
                .check_fragment_shorthand = self.options.react_jsx_key_check_fragment_shorthand,
            });
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
        if (self.options.alipay_ant_jsx_handler_names) {
            try alipay_ant_jsx_handler_names.check(self.allocator, self.diagnostics, ctx.tree, attribute, index);
        }
        if (self.options.react_no_danger) {
            try react_no_danger.check(self.allocator, self.diagnostics, ctx.tree, attribute, index, ctx.path.ancestor(1));
        }
        if (self.options.react_jsx_boolean_value) {
            try react_jsx_boolean_value.checkWithStyle(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                attribute,
                index,
                self.options.react_jsx_boolean_value_style,
            );
        }
        if (self.options.react_style_prop_object) {
            try react_style_prop_object.checkJSXAttribute(self.allocator, self.diagnostics, ctx.tree, attribute, index, ctx.path.ancestor(1), &self.react_style_prop_object_bindings);
        }
        if (self.options.react_no_children_prop) {
            try react_no_children_prop.checkJSXAttribute(self.allocator, self.diagnostics, ctx.tree, attribute, index);
        }
        if (self.options.react_no_string_refs) {
            try react_no_string_refs.check(self.allocator, self.diagnostics, ctx.tree, attribute, index, .{
                .no_template_literals = self.options.react_no_string_refs_no_template_literals,
            });
        }
        if (self.options.react_no_array_index_key) {
            try react_no_array_index_key.checkJSXAttribute(self.allocator, self.diagnostics, ctx.tree, attribute, self.react_no_array_index_key_state);
        }
        if (self.options.react_jsx_no_bind) {
            try react_jsx_no_bind.checkJSXAttribute(self.allocator, self.diagnostics, ctx.tree, attribute, index, self.react_jsx_no_bind_state, ctx.path.ancestor(1), .{
                .allow_arrow_functions = self.options.react_jsx_no_bind_allow_arrow_functions,
                .allow_functions = self.options.react_jsx_no_bind_allow_functions,
                .allow_bind = self.options.react_jsx_no_bind_allow_bind,
                .ignore_refs = self.options.react_jsx_no_bind_ignore_refs,
                .ignore_dom_components = self.options.react_jsx_no_bind_ignore_dom_components,
            });
        }
        if (self.options.react_no_unknown_property) {
            try react_no_unknown_property.check(self.allocator, self.diagnostics, ctx.tree, attribute, index, ctx.path.ancestor(1), .{
                .ignore = self.options.react_no_unknown_property_ignore,
                .require_data_lowercase = self.options.react_no_unknown_property_require_data_lowercase,
            });
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
        if (self.options.react_jsx_filename_extension) {
            try react_jsx_filename_extension.check(self.allocator, self.diagnostics, ctx.tree, self.file_path, index, &self.react_jsx_filename_extension_state, .{
                .extensions = self.options.react_jsx_filename_extension_extensions,
            });
        }
        if (self.options.react_button_has_type) {
            try react_button_has_type.checkJSXElement(self.allocator, self.diagnostics, ctx.tree, element, index, .{
                .allow_button = self.options.react_button_has_type_button,
                .allow_submit = self.options.react_button_has_type_submit,
                .allow_reset = self.options.react_button_has_type_reset,
            });
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

    pub fn enter_jsx_fragment(
        self: *BasicVisitor,
        _: ast.JSXFragment,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.react_jsx_filename_extension) {
            try react_jsx_filename_extension.check(self.allocator, self.diagnostics, ctx.tree, self.file_path, index, &self.react_jsx_filename_extension_state, .{
                .extensions = self.options.react_jsx_filename_extension_extensions,
            });
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
            try react_jsx_no_duplicate_props.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, opening, .{
                .ignore_case = self.options.react_jsx_no_duplicate_props_ignore_case,
            });
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
        if (self.options.alipay_ant_prefer_safe_image_renderer) {
            try alipay_ant_prefer_safe_image_renderer.check(self.allocator, self.diagnostics, ctx.tree, opening);
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
            try react_jsx_no_target_blank.check(self.allocator, self.diagnostics, ctx.tree, opening, index, .{
                .allow_referrer = self.options.react_jsx_no_target_blank_allow_referrer,
                .enforce_dynamic_links = self.options.react_jsx_no_target_blank_enforce_dynamic_links,
            });
        }
        if (self.options.react_jsx_pascal_case) {
            try react_jsx_pascal_case.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, opening, index, .{
                .allow_all_caps = self.options.react_jsx_pascal_case_allow_all_caps,
                .ignore = self.options.react_jsx_pascal_case_ignore,
            });
        }
        if (self.options.react_self_closing_comp) {
            try react_self_closing_comp.check(self.allocator, self.diagnostics, ctx.tree, opening, index, ctx.path.ancestor(1), .{
                .component = self.options.react_self_closing_comp_component,
                .html = self.options.react_self_closing_comp_html,
            });
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
            try react_no_unescaped_entities.check(self.allocator, self.diagnostics, ctx.tree, index, .{
                .forbid_gt = self.options.react_no_unescaped_entities_forbid_gt,
                .forbid_double_quote = self.options.react_no_unescaped_entities_forbid_double_quote,
                .forbid_single_quote = self.options.react_no_unescaped_entities_forbid_single_quote,
                .forbid_closing_brace = self.options.react_no_unescaped_entities_forbid_closing_brace,
            });
        }
        return .proceed;
    }

    pub fn enter_object_expression(
        self: *BasicVisitor,
        expression: ast.ObjectExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.accessor_pairs) {
            try accessor_pairs.checkObjectExpressionWithOptions(self.allocator, self.diagnostics, ctx.tree, expression, .{
                .get_without_set = self.options.accessor_pairs_get_without_set == .yes,
                .set_without_get = self.options.accessor_pairs_set_without_get == .yes,
                .enforce_for_class_members = self.options.accessor_pairs_enforce_for_class_members == .yes,
            });
        }
        if (self.options.grouped_accessor_pairs) {
            try grouped_accessor_pairs.checkObjectExpressionWithStyle(self.allocator, self.diagnostics, ctx.tree, expression, groupedAccessorPairsStyle(self.options.grouped_accessor_pairs_style));
        }
        if (self.options.no_dupe_keys) {
            try no_dupe_keys.check(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        if (self.options.no_useless_computed_key) {
            try no_useless_computed_key.checkObjectExpression(self.allocator, self.diagnostics, ctx.tree, expression);
        }
        if (self.options.react_prefer_es6_class) {
            try react_prefer_es6_class.checkObjectExpression(self.allocator, self.diagnostics, ctx.tree, index, ctx.path.ancestor(1), reactPreferEs6ClassStyle(self.options.react_prefer_es6_class_style));
        }
        if (self.options.react_no_deprecated) {
            try react_no_deprecated.checkObjectExpression(self.allocator, self.diagnostics, ctx.tree, index, expression, ctx.path.ancestor(1));
        }
        if (self.options.react_no_typos) {
            try react_no_typos.checkObjectExpression(self.allocator, self.diagnostics, ctx.tree, expression, index, ctx.path.ancestor(1), self.react_no_typos_state);
        }
        if (self.options.react_no_unused_state) {
            try react_no_unused_state.enterObjectExpression(self.allocator, ctx.tree, index, ctx.path.parent(), &self.react_no_unused_state_state);
        }
        if (self.options.react_forbid_prop_types) {
            try react_forbid_prop_types.checkObjectExpression(self.allocator, self.diagnostics, ctx.tree, expression, self.react_forbid_prop_types_state, .{
                .forbid_any = self.options.react_forbid_prop_types_forbid_any,
                .forbid_array = self.options.react_forbid_prop_types_forbid_array,
                .forbid_object = self.options.react_forbid_prop_types_forbid_object,
            });
        }
        return .proceed;
    }

    pub fn exit_object_expression(
        self: *BasicVisitor,
        _: ast.ObjectExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        if (self.options.react_no_unused_state) {
            react_no_unused_state.exitObjectExpression(self.allocator, self.diagnostics, ctx.tree, index, &self.react_no_unused_state_state) catch {};
        }
    }

    pub fn enter_object_property(
        self: *BasicVisitor,
        property: ast.ObjectProperty,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.object_shorthand) {
            try object_shorthand.checkWithOptions(self.allocator, self.diagnostics, ctx.tree, property, index, .{
                .style = self.options.object_shorthand_style,
                .avoid_quotes = self.options.object_shorthand_avoid_quotes,
                .ignore_constructors = self.options.object_shorthand_ignore_constructors,
                .avoid_explicit_return_arrows = self.options.object_shorthand_avoid_explicit_return_arrows,
            });
        }
        if (self.options.func_name_matching) {
            try func_name_matching.checkObjectPropertyWithOptions(self.allocator, self.diagnostics, ctx.tree, property, .{
                .style = funcNameMatchingStyle(self.options.func_name_matching_style),
            });
        }
        if (self.options.no_underscore_dangle) {
            try no_underscore_dangle.checkObjectPropertyWithOptions(self.allocator, self.diagnostics, ctx.tree, property, .{
                .allow = self.options.no_underscore_dangle_allow,
                .enforce_in_method_names = self.options.no_underscore_dangle_enforce_in_method_names,
            });
        }
        if (self.options.react_no_unused_state) {
            try react_no_unused_state.enterObjectProperty(self.allocator, ctx.tree, property, index, ctx.path.parent(), &self.react_no_unused_state_state);
        }
        return .proceed;
    }

    pub fn exit_object_property(
        self: *BasicVisitor,
        property: ast.ObjectProperty,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        if (self.options.react_no_unused_state) {
            react_no_unused_state.exitObjectProperty(property, ctx.tree, ctx.path.parent(), &self.react_no_unused_state_state);
        }
    }

    pub fn enter_object_pattern(
        self: *BasicVisitor,
        pattern: ast.ObjectPattern,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_empty_pattern) {
            try no_empty_pattern.checkObjectPatternWithOptions(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                pattern,
                index,
                ctx.path.parent(),
                ctx.path.ancestor(2),
                .{
                    .allow_object_patterns_as_parameters = self.options.no_empty_pattern_allow_object_patterns_as_parameters,
                },
            );
        }
        if (self.options.no_useless_rename) {
            try no_useless_rename.checkObjectPatternWithOptions(self.allocator, self.diagnostics, ctx.tree, pattern, self.noUselessRenameOptions());
        }
        if (self.options.no_useless_computed_key) {
            try no_useless_computed_key.checkObjectPattern(self.allocator, self.diagnostics, ctx.tree, pattern);
        }
        return .proceed;
    }

    pub fn enter_class_body(
        self: *BasicVisitor,
        body: ast.ClassBody,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_extra_semi and !self.options.typescript_eslint_no_extra_semi) {
            try no_extra_semi.checkClassBody(self.allocator, self.diagnostics, ctx.tree, body, index);
        }
        if (self.options.accessor_pairs) {
            try accessor_pairs.checkClassBodyWithOptions(self.allocator, self.diagnostics, ctx.tree, body, .{
                .get_without_set = self.options.accessor_pairs_get_without_set == .yes,
                .set_without_get = self.options.accessor_pairs_set_without_get == .yes,
                .enforce_for_class_members = self.options.accessor_pairs_enforce_for_class_members == .yes,
            });
        }
        if (self.options.grouped_accessor_pairs) {
            try grouped_accessor_pairs.checkClassBodyWithStyle(self.allocator, self.diagnostics, ctx.tree, body, groupedAccessorPairsStyle(self.options.grouped_accessor_pairs_style));
        }
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
        if (self.options.no_useless_computed_key and self.options.no_useless_computed_key_enforce_for_class_members == .yes) {
            try no_useless_computed_key.checkMethodDefinition(self.allocator, self.diagnostics, ctx.tree, method, index);
        }
        if (self.options.no_underscore_dangle) {
            try no_underscore_dangle.checkMethodDefinitionWithOptions(self.allocator, self.diagnostics, ctx.tree, method, .{
                .allow = self.options.no_underscore_dangle_allow,
                .enforce_in_method_names = self.options.no_underscore_dangle_enforce_in_method_names,
            });
        }
        if (self.options.typescript_eslint_explicit_member_accessibility) {
            try typescript_eslint_explicit_member_accessibility.checkMethodDefinition(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                method,
                index,
                self.options.typescript_eslint_explicit_member_accessibility_accessibility,
            );
        }
        if (self.options.typescript_eslint_class_literal_property_style) {
            try typescript_eslint_class_literal_property_style.checkMethodDefinition(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                method,
                index,
                self.options.typescript_eslint_class_literal_property_style_style,
            );
        }
        if (self.options.react_no_typos) {
            try react_no_typos.checkMethodDefinition(self.allocator, self.diagnostics, ctx.tree, method, index, ctx);
        }
        if (self.options.react_forbid_prop_types) {
            try react_forbid_prop_types.checkMethodDefinition(self.allocator, self.diagnostics, ctx.tree, method, self.react_forbid_prop_types_state, .{
                .forbid_any = self.options.react_forbid_prop_types_forbid_any,
                .forbid_array = self.options.react_forbid_prop_types_forbid_array,
                .forbid_object = self.options.react_forbid_prop_types_forbid_object,
            });
        }
        if (self.options.react_no_unused_state) {
            try react_no_unused_state.enterMethodDefinition(self.allocator, ctx.tree, method, &self.react_no_unused_state_state);
        }
        return .proceed;
    }

    pub fn exit_method_definition(
        self: *BasicVisitor,
        method: ast.MethodDefinition,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        if (self.options.react_no_unused_state) {
            react_no_unused_state.exitMethodDefinition(method, &self.react_no_unused_state_state);
        }
    }

    pub fn enter_property_definition(
        self: *BasicVisitor,
        property: ast.PropertyDefinition,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_useless_computed_key and self.options.no_useless_computed_key_enforce_for_class_members == .yes) {
            try no_useless_computed_key.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property, index);
        }
        if (self.options.no_underscore_dangle) {
            try no_underscore_dangle.checkPropertyDefinitionWithOptions(self.allocator, self.diagnostics, ctx.tree, property, .{
                .allow = self.options.no_underscore_dangle_allow,
                .enforce_in_class_fields = self.options.no_underscore_dangle_enforce_in_class_fields,
            });
        }
        if (self.options.no_multi_assign) {
            try no_multi_assign.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property);
        }
        if (self.options.typescript_eslint_explicit_member_accessibility) {
            try typescript_eslint_explicit_member_accessibility.checkPropertyDefinition(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                property,
                index,
                self.options.typescript_eslint_explicit_member_accessibility_accessibility,
            );
        }
        if (self.options.typescript_eslint_prefer_as_const) {
            try typescript_eslint_prefer_as_const.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property);
        }
        if (self.options.typescript_eslint_no_inferrable_types) {
            try typescript_eslint_no_inferrable_types.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property, .{
                .ignore_parameters = self.options.typescript_eslint_no_inferrable_types_ignore_parameters,
                .ignore_properties = self.options.typescript_eslint_no_inferrable_types_ignore_properties,
            });
        }
        if (self.options.typescript_eslint_typedef and self.options.typescript_eslint_typedef_member_variable_declaration) {
            try typescript_eslint_typedef.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property, index);
        }
        if (self.options.typescript_eslint_class_literal_property_style) {
            try typescript_eslint_class_literal_property_style.checkPropertyDefinition(
                self.allocator,
                self.diagnostics,
                ctx.tree,
                property,
                index,
                self.options.typescript_eslint_class_literal_property_style_style,
            );
        }
        if (self.options.func_name_matching) {
            try func_name_matching.checkPropertyDefinitionWithOptions(self.allocator, self.diagnostics, ctx.tree, property, .{
                .style = funcNameMatchingStyle(self.options.func_name_matching_style),
            });
        }
        if (self.options.react_no_typos) {
            try react_no_typos.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property, ctx, self.react_no_typos_state);
        }
        if (self.options.react_forbid_prop_types) {
            try react_forbid_prop_types.checkPropertyDefinition(self.allocator, self.diagnostics, ctx.tree, property, self.react_forbid_prop_types_state, .{
                .forbid_any = self.options.react_forbid_prop_types_forbid_any,
                .forbid_array = self.options.react_forbid_prop_types_forbid_array,
                .forbid_object = self.options.react_forbid_prop_types_forbid_object,
            });
        }
        if (self.options.react_no_unused_state) {
            try react_no_unused_state.enterPropertyDefinition(self.allocator, ctx.tree, property, &self.react_no_unused_state_state);
        }
        return .proceed;
    }

    pub fn exit_property_definition(
        self: *BasicVisitor,
        property: ast.PropertyDefinition,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        if (self.options.react_no_unused_state) {
            react_no_unused_state.exitPropertyDefinition(property, ctx.tree, &self.react_no_unused_state_state);
        }
    }

    pub fn enter_spread_element(
        self: *BasicVisitor,
        element: ast.SpreadElement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) traverser.Action {
        if (self.options.react_no_unused_state) {
            react_no_unused_state.checkSpreadElement(ctx.tree, element, &self.react_no_unused_state_state);
        }
        return .proceed;
    }

    pub fn enter_jsx_spread_attribute(
        self: *BasicVisitor,
        attribute: ast.JSXSpreadAttribute,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) traverser.Action {
        if (self.options.react_no_unused_state) {
            react_no_unused_state.checkJSXSpreadAttribute(ctx.tree, attribute, &self.react_no_unused_state_state);
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
            try no_useless_rename.checkImportSpecifierWithOptions(self.allocator, self.diagnostics, ctx.tree, specifier, index, self.noUselessRenameOptions());
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
            try no_useless_rename.checkExportSpecifierWithOptions(self.allocator, self.diagnostics, ctx.tree, specifier, index, self.noUselessRenameOptions());
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
            try no_useless_escape.checkRegExpLiteralWithOptions(self.allocator, self.diagnostics, ctx.tree, literal, index, .{
                .allow_regex_characters = self.options.no_useless_escape_allow_regex_characters,
            });
        }
        return .proceed;
    }
};
