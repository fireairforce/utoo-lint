const std = @import("std");
const parser = @import("parser");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const Severity = enum {
    @"error",
    warning,

    pub fn toString(self: Severity) []const u8 {
        return switch (self) {
            .@"error" => "error",
            .warning => "warning",
        };
    }
};

pub const NoConfusingArrowAllowParens = enum {
    yes,
    no,
};

pub const NoUnderscoreDangleAllowFunctionParams = enum {
    yes,
    no,
};

pub const NoUnderscoreDangleAllowDestructuring = enum {
    yes,
    no,
};

pub const NoWarningCommentsLocation = enum {
    start,
    anywhere,
};

pub const NoWarningCommentsDecoration = enum {
    none,
    asterisk,
    slash_asterisk,
};

pub const WrapIifeStyle = enum {
    outside,
    inside,
    any,
};

pub const AccessorPairsGetWithoutSet = enum {
    yes,
    no,
};

pub const GroupedAccessorPairsStyle = enum {
    any_order,
    get_before_set,
    set_before_get,
};

pub const LogicalAssignmentOperatorsEnforceForIfStatements = enum {
    yes,
    no,
};

pub const FuncNamesStyle = enum {
    always,
    as_needed,
};

pub const ArrayCallbackReturnAllowImplicit = enum {
    yes,
    no,
};

pub const Options = struct {
    accessor_pairs: bool = true,
    accessor_pairs_get_without_set: AccessorPairsGetWithoutSet = .no,
    array_callback_return: bool = true,
    array_callback_return_allow_implicit: ArrayCallbackReturnAllowImplicit = .yes,
    block_scoped_var: bool = true,
    capitalized_comments: bool = true,
    consistent_return: bool = true,
    constructor_super: bool = true,
    curly: bool = true,
    dot_notation: bool = true,
    typescript_eslint_dot_notation: bool = true,
    default_case: bool = true,
    default_case_last: bool = true,
    default_param_last: bool = true,
    eol_last: bool = true,
    eslint_comments_no_restricted_disable: bool = true,
    eslint_comments_no_restricted_disable_no_nested_ternary: bool = false,
    for_direction: bool = true,
    func_name_matching: bool = true,
    func_names: bool = true,
    func_names_style: FuncNamesStyle = .always,
    getter_return: bool = true,
    grouped_accessor_pairs: bool = true,
    grouped_accessor_pairs_style: GroupedAccessorPairsStyle = .any_order,
    guard_for_in: bool = true,
    linebreak_style: bool = true,
    logical_assignment_operators: bool = true,
    logical_assignment_operators_enforce_for_if_statements: LogicalAssignmentOperatorsEnforceForIfStatements = .no,
    new_cap: bool = true,
    new_parens: bool = true,
    no_async_promise_executor: bool = true,
    no_array_constructor: bool = true,
    no_await_in_loop: bool = true,
    no_alert: bool = true,
    no_bitwise: bool = true,
    no_buffer_constructor: bool = true,
    no_caller: bool = true,
    no_case_declarations: bool = true,
    no_class_assign: bool = true,
    no_confusing_arrow: bool = true,
    no_confusing_arrow_allow_parens: NoConfusingArrowAllowParens = .yes,
    no_cond_assign: bool = true,
    no_compare_neg_zero: bool = true,
    no_constant_condition: bool = true,
    no_const_assign: bool = true,
    no_control_regex: bool = true,
    no_console: bool = true,
    no_comma_operator: bool = true,
    no_continue: bool = true,
    no_constructor_return: bool = true,
    no_debugger: bool = true,
    no_dupe_else_if: bool = true,
    no_duplicate_case: bool = true,
    no_dupe_args: bool = true,
    no_dupe_class_members: bool = true,
    typescript_eslint_no_dupe_class_members: bool = true,
    no_dupe_keys: bool = true,
    no_duplicate_imports: bool = true,
    no_delete_var: bool = true,
    no_div_regex: bool = true,
    no_empty: bool = true,
    no_empty_block_statements: bool = true,
    no_empty_character_class: bool = true,
    no_empty_function: bool = true,
    no_empty_pattern: bool = true,
    no_empty_static_block: bool = true,
    no_else_return: bool = true,
    no_eq_null: bool = true,
    no_eval: bool = true,
    no_ex_assign: bool = true,
    no_extend_native: bool = true,
    no_extra_bind: bool = true,
    no_extra_label: bool = true,
    no_extra_semi: bool = true,
    no_extra_boolean_cast: bool = true,
    no_floating_decimal: bool = true,
    no_fallthrough: bool = true,
    no_for_in: bool = true,
    no_func_assign: bool = true,
    no_global_assign: bool = true,
    no_global_is_finite: bool = true,
    no_global_is_nan: bool = true,
    no_implicit_coercion: bool = true,
    no_implied_eval: bool = true,
    no_import_assign: bool = true,
    alipay_ant_disallow_typos: bool = true,
    alipay_ant_exhaustive_deps: bool = true,
    alipay_ant_jsx_handler_names: bool = true,
    alipay_ant_no_deprecated_dependence: bool = true,
    alipay_ant_no_deprecated_dependence_profile: DeprecatedDependenceProfile = .default,
    alipay_ant_no_deprecated_variable: bool = true,
    alipay_ant_no_import_files_from_pages_in_common: bool = true,
    alipay_ant_no_negative_conditionals: bool = true,
    alipay_ant_no_import_src: bool = true,
    alipay_ant_no_phantom_dependencies: bool = true,
    alipay_ant_no_too_large_file: bool = true,
    alipay_ant_prefer_elseif_end_with_else: bool = true,
    alipay_ant_prefer_catch_unsafe_func_call: bool = true,
    alipay_ant_prefer_click_with_debounce: bool = true,
    alipay_ant_prefer_import_as_required: bool = true,
    alipay_ant_no_spread_params: bool = true,
    alipay_ant_prefer_resource_from_huamei: bool = true,
    alipay_ant_prefer_render_img_with_promo_mobile: bool = true,
    alipay_ant_prefer_import_from_stdlib: bool = true,
    alipay_spmlint_use_labeled_spm: bool = true,
    alipay_spmlint_valid_manual_click: bool = true,
    alipay_spmlint_valid_manual_expo: bool = true,
    alipay_spmlint_valid_manual_param: bool = true,
    alipay_spmlint_valid_manual_pv: bool = true,
    import_default: bool = true,
    import_export: bool = true,
    import_first: bool = true,
    import_named: bool = true,
    import_namespace: bool = true,
    import_newline_after_import: bool = true,
    import_no_amd: bool = true,
    import_no_cycle: bool = true,
    import_no_duplicates: bool = true,
    import_no_named_as_default: bool = true,
    import_no_named_as_default_member: bool = true,
    import_no_unresolved: bool = true,
    import_no_self_import: bool = true,
    jsx_a11y_alt_text: bool = true,
    jsx_a11y_anchor_has_content: bool = true,
    jsx_a11y_aria_props: bool = true,
    jsx_a11y_aria_proptypes: bool = true,
    jsx_a11y_aria_role: bool = true,
    jsx_a11y_aria_unsupported_elements: bool = true,
    jsx_a11y_iframe_has_title: bool = true,
    jsx_a11y_img_redundant_alt: bool = true,
    jsx_a11y_no_access_key: bool = true,
    jsx_a11y_no_distracting_elements: bool = true,
    jsx_a11y_role_has_required_aria_props: bool = true,
    jsx_a11y_role_supports_aria_props: bool = true,
    jsx_a11y_scope: bool = true,
    no_invalid_regexp: bool = true,
    no_irregular_whitespace: bool = true,
    no_inline_comments: bool = true,
    no_inner_declarations: bool = true,
    no_iterator: bool = true,
    no_label_var: bool = true,
    no_labels: bool = true,
    no_lone_blocks: bool = true,
    no_lonely_if: bool = true,
    no_loop_func: bool = true,
    no_loss_of_precision: bool = true,
    no_multi_str: bool = true,
    no_multi_assign: bool = true,
    no_multi_spaces: bool = true,
    no_mixed_spaces_and_tabs: bool = true,
    no_misleading_character_class: bool = true,
    no_multiple_empty_lines: bool = true,
    no_nonoctal_decimal_escape: bool = true,
    no_new: bool = true,
    no_nested_ternary: bool = true,
    no_negated_condition: bool = true,
    no_new_native_nonconstructor: bool = true,
    no_new_func: bool = true,
    no_new_require: bool = true,
    no_obj_calls: bool = true,
    no_new_object: bool = true,
    no_new_symbol: bool = true,
    no_new_wrappers: bool = true,
    no_octal: bool = true,
    no_octal_escape: bool = true,
    no_object_constructor: bool = true,
    no_param_reassign: bool = true,
    no_path_concat: bool = true,
    no_plusplus: bool = true,
    no_promise_executor_return: bool = true,
    no_proto: bool = true,
    no_process_env: bool = true,
    no_process_exit: bool = true,
    no_prototype_builtins: bool = true,
    no_redeclare: bool = true,
    no_regex_spaces: bool = true,
    no_return_await: bool = true,
    no_return_assign: bool = true,
    no_useless_return: bool = true,
    no_script_url: bool = true,
    no_self_assign: bool = true,
    no_self_compare: bool = true,
    no_setter_return: bool = true,
    no_shadow: bool = true,
    no_shadow_restricted_names: bool = true,
    no_sequences: bool = true,
    no_sparse_arrays: bool = true,
    no_ternary: bool = true,
    no_template_curly_in_string: bool = true,
    no_throw_literal: bool = true,
    no_this_before_super: bool = true,
    no_tabs: bool = true,
    no_trailing_spaces: bool = true,
    no_unreachable: bool = true,
    no_undef_init: bool = true,
    no_underscore_dangle: bool = true,
    no_underscore_dangle_allow_after_this: bool = false,
    no_underscore_dangle_allow_after_super: bool = false,
    no_underscore_dangle_allow_after_this_constructor: bool = false,
    no_underscore_dangle_allow_function_params: NoUnderscoreDangleAllowFunctionParams = .yes,
    no_underscore_dangle_allow_in_array_destructuring: NoUnderscoreDangleAllowDestructuring = .yes,
    no_underscore_dangle_allow_in_object_destructuring: NoUnderscoreDangleAllowDestructuring = .yes,
    no_underscore_dangle_enforce_in_method_names: bool = false,
    no_underscore_dangle_enforce_in_class_fields: bool = false,
    no_undefined: bool = true,
    unicode_bom: bool = true,
    no_unneeded_ternary: bool = true,
    no_unused_labels: bool = true,
    no_unsafe_finally: bool = true,
    no_unsafe_negation: bool = true,
    no_useless_computed_key: bool = true,
    no_useless_call: bool = true,
    no_useless_concat: bool = true,
    no_useless_constructor: bool = true,
    no_useless_catch: bool = true,
    no_useless_escape: bool = true,
    no_useless_rename: bool = true,
    no_unused_expressions: bool = true,
    typescript_eslint_no_unused_expressions: bool = true,
    no_warning_comments: bool = true,
    no_warning_comments_location: NoWarningCommentsLocation = .start,
    no_warning_comments_decoration: NoWarningCommentsDecoration = .none,
    no_void: bool = true,
    no_with: bool = true,
    no_var: bool = true,
    object_shorthand: bool = true,
    one_var: bool = true,
    operator_assignment: bool = true,
    eqeqeq: bool = true,
    use_isnan: bool = true,
    no_unused_vars: bool = true,
    no_use_before_define: bool = true,
    no_undef: bool = true,
    prefer_const: bool = true,
    prefer_exponentiation_operator: bool = true,
    prefer_numeric_literals: bool = true,
    prefer_object_has_own: bool = true,
    prefer_promise_reject_errors: bool = true,
    prefer_destructuring: bool = true,
    prefer_regex_literals: bool = true,
    prefer_rest_params: bool = true,
    prefer_object_spread: bool = true,
    prefer_spread: bool = true,
    prefer_template: bool = true,
    react_default_props_match_prop_types: bool = true,
    react_display_name: bool = true,
    react_jsx_boolean_value: bool = true,
    react_jsx_filename_extension: bool = true,
    react_jsx_no_duplicate_props: bool = true,
    react_jsx_no_comment_textnodes: bool = true,
    react_jsx_no_bind: bool = true,
    react_jsx_key: bool = true,
    react_button_has_type: bool = true,
    react_require_render_return: bool = true,
    react_jsx_no_target_blank: bool = true,
    react_jsx_no_undef: bool = true,
    react_jsx_pascal_case: bool = true,
    react_jsx_uses_react: bool = true,
    react_jsx_uses_vars: bool = true,
    react_no_danger: bool = true,
    react_no_danger_with_children: bool = true,
    react_no_access_state_in_setstate: bool = true,
    react_no_deprecated: bool = true,
    react_forbid_prop_types: bool = true,
    react_no_array_index_key: bool = true,
    react_no_children_prop: bool = true,
    react_no_find_dom_node: bool = true,
    react_no_is_mounted: bool = true,
    react_no_multi_comp: bool = true,
    react_no_redundant_should_component_update: bool = true,
    react_no_render_return_value: bool = true,
    react_no_will_update_set_state: bool = true,
    react_no_this_in_sfc: bool = true,
    react_no_typos: bool = true,
    react_no_unknown_property: bool = true,
    react_prop_types: bool = true,
    react_no_unused_prop_types: bool = true,
    react_no_unused_state: bool = true,
    react_no_string_refs: bool = true,
    react_no_unescaped_entities: bool = true,
    react_prefer_es6_class: bool = true,
    react_self_closing_comp: bool = true,
    react_style_prop_object: bool = true,
    react_void_dom_elements_no_children: bool = true,
    react_hooks_rules_of_hooks: bool = true,
    radix: bool = true,
    require_await: bool = true,
    require_atomic_updates: bool = true,
    require_yield: bool = true,
    spaced_comment: bool = true,
    symbol_description: bool = true,
    typescript_eslint_adjacent_overload_signatures: bool = true,
    typescript_eslint_array_type: bool = true,
    typescript_eslint_class_literal_property_style: bool = true,
    typescript_eslint_consistent_type_assertions: bool = true,
    typescript_eslint_consistent_type_definitions: bool = true,
    typescript_eslint_no_array_constructor: bool = true,
    typescript_eslint_ban_types: bool = true,
    typescript_eslint_ban_ts_comment: bool = true,
    typescript_eslint_ban_tslint_comment: bool = true,
    typescript_eslint_explicit_member_accessibility: bool = true,
    typescript_eslint_member_ordering: bool = true,
    typescript_eslint_method_signature_style: bool = true,
    typescript_eslint_no_confusing_non_null_assertion: bool = true,
    typescript_eslint_no_empty_function: bool = true,
    typescript_eslint_no_empty_interface: bool = true,
    typescript_eslint_no_extra_semi: bool = true,
    typescript_eslint_no_extra_non_null_assertion: bool = true,
    typescript_eslint_no_duplicate_enum_values: bool = true,
    typescript_eslint_no_inferrable_types: bool = true,
    typescript_eslint_no_invalid_void_type: bool = true,
    typescript_eslint_no_loss_of_precision: bool = true,
    typescript_eslint_no_loop_func: bool = true,
    typescript_eslint_no_misused_new: bool = true,
    typescript_eslint_no_non_null_asserted_optional_chain: bool = true,
    typescript_eslint_no_namespace: bool = true,
    typescript_eslint_no_redeclare: bool = true,
    typescript_eslint_no_require_imports: bool = true,
    typescript_eslint_no_shadow: bool = true,
    typescript_eslint_no_this_alias: bool = true,
    typescript_eslint_no_unsafe_declaration_merging: bool = true,
    typescript_eslint_triple_slash_reference: bool = true,
    typescript_eslint_typedef: bool = true,
    typescript_eslint_unified_signatures: bool = true,
    typescript_eslint_no_unnecessary_parameter_property_assignment: bool = true,
    typescript_eslint_no_unnecessary_type_constraint: bool = true,
    typescript_eslint_no_useless_constructor: bool = true,
    typescript_eslint_no_useless_empty_export: bool = true,
    typescript_eslint_no_unused_vars: bool = true,
    typescript_eslint_no_use_before_define: bool = true,
    typescript_eslint_no_var_requires: bool = true,
    typescript_eslint_no_wrapper_object_types: bool = true,
    typescript_eslint_prefer_as_const: bool = true,
    typescript_eslint_prefer_namespace_keyword: bool = true,
    typescript_eslint_restrict_plus_operands: bool = true,
    parser_semantic_errors: bool = true,
    valid_typeof: bool = true,
    vars_on_top: bool = true,
    wrap_iife: bool = true,
    wrap_iife_style: WrapIifeStyle = .outside,
    yoda: bool = true,

    pub fn allDisabled() Options {
        var options = Options{};
        inline for (@typeInfo(Options).@"struct".fields) |field| {
            if (field.type == bool) {
                @field(options, field.name) = false;
            }
        }
        return options;
    }

    pub fn setByCliName(self: *Options, cli_name: []const u8, value: bool) bool {
        @setEvalBranchQuota(10000);

        if (std.mem.eql(u8, cli_name, "semantic-errors")) {
            self.parser_semantic_errors = value;
            return true;
        }

        if (std.mem.eql(u8, cli_name, "prettier/prettier")) {
            return true;
        }

        if (std.mem.startsWith(u8, cli_name, "@typescript-eslint/")) {
            const typescript_rule_name = cli_name["@typescript-eslint/".len..];
            inline for (@typeInfo(Options).@"struct".fields) |field| {
                if (field.type == bool) {
                    if (comptime fieldNameStartsWith(field.name, "typescript_eslint_")) {
                        if (cliNameMatchesFieldName(field.name["typescript_eslint_".len..], typescript_rule_name)) {
                            @field(self, field.name) = value;
                            return true;
                        }
                    }
                }
            }
            return false;
        }

        if (std.mem.startsWith(u8, cli_name, "import/")) {
            return self.setByPrefixedRuleName("import_", cli_name["import/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "eslint-comments/")) {
            return self.setByPrefixedRuleName("eslint_comments_", cli_name["eslint-comments/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "@alipay/ant/")) {
            return self.setByPrefixedRuleName("alipay_ant_", cli_name["@alipay/ant/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "@alipay/spmLint/")) {
            return self.setByPrefixedRuleName("alipay_spmlint_", cli_name["@alipay/spmLint/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "jsx-a11y/")) {
            return self.setByPrefixedRuleName("jsx_a11y_", cli_name["jsx-a11y/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "react/")) {
            return self.setByPrefixedRuleName("react_", cli_name["react/".len..], value);
        }

        if (std.mem.startsWith(u8, cli_name, "react-hooks/")) {
            return self.setByPrefixedRuleName("react_hooks_", cli_name["react-hooks/".len..], value);
        }

        inline for (@typeInfo(Options).@"struct".fields) |field| {
            if (field.type == bool and cliNameMatchesFieldName(field.name, cli_name)) {
                @field(self, field.name) = value;
                return true;
            }
        }
        return false;
    }

    pub fn setByRuleConfigValue(self: *Options, cli_name: []const u8, value: std.json.Value) RuleConfigError!void {
        const enabled = try ruleConfigValueToBool(value);
        if (!self.setByCliName(cli_name, enabled)) return error.UnknownRule;
        if (std.mem.eql(u8, cli_name, "@alipay/ant/no-deprecated-dependence")) {
            self.alipay_ant_no_deprecated_dependence_profile = deprecatedDependenceProfileFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "eslint-comments/no-restricted-disable")) {
            self.eslint_comments_no_restricted_disable_no_nested_ternary = noRestrictedDisableRestrictsNoNestedTernary(value);
        }
    }

    pub const RuleConfigError = error{
        EmptyRuleConfigArray,
        UnknownRule,
        UnsupportedRuleConfigValue,
    };

    fn ruleConfigValueToBool(value: std.json.Value) RuleConfigError!bool {
        return switch (value) {
            .bool => |enabled| enabled,
            .integer => |severity| switch (severity) {
                0 => false,
                1, 2 => true,
                else => error.UnsupportedRuleConfigValue,
            },
            .string => |severity| ruleSeverityStringToBool(severity) orelse error.UnsupportedRuleConfigValue,
            .array => |items| {
                if (items.items.len == 0) return error.EmptyRuleConfigArray;
                return ruleConfigValueToBool(items.items[0]);
            },
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn ruleSeverityStringToBool(severity: []const u8) ?bool {
        if (std.ascii.eqlIgnoreCase(severity, "off") or std.mem.eql(u8, severity, "0")) return false;
        if (std.ascii.eqlIgnoreCase(severity, "warn") or
            std.ascii.eqlIgnoreCase(severity, "warning") or
            std.ascii.eqlIgnoreCase(severity, "error") or
            std.ascii.eqlIgnoreCase(severity, "on") or
            std.mem.eql(u8, severity, "1") or
            std.mem.eql(u8, severity, "2"))
        {
            return true;
        }
        return null;
    }

    fn deprecatedDependenceProfileFromConfig(value: std.json.Value) DeprecatedDependenceProfile {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .default,
        };
        if (items.len < 2) return .default;
        const config = switch (items[1]) {
            .object => |object| object,
            else => return .default,
        };
        const external_packages = switch (config.get("externalPackages") orelse return .default) {
            .object => |object| object,
            else => return .default,
        };

        if (external_packages.get("@alipay/dp-anyshare-react") != null or
            external_packages.get("@alipay/yuyan-monitor-web") != null or
            external_packages.get("moment") != null)
        {
            return .ivy;
        }
        if (external_packages.get("@alipay/one-bridge") != null or
            external_packages.get("@alipay/bx-rpc") != null or
            external_packages.get("hooxjs") != null)
        {
            return .insurance;
        }
        return .default;
    }

    fn noRestrictedDisableRestrictsNoNestedTernary(value: std.json.Value) bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;
        for (items[1..]) |item| {
            const rule = switch (item) {
                .string => |rule| rule,
                else => continue,
            };
            if (std.mem.eql(u8, rule, "no-nested-ternary")) return true;
        }
        return false;
    }

    fn setByPrefixedRuleName(self: *Options, comptime field_prefix: []const u8, rule_name: []const u8, value: bool) bool {
        inline for (@typeInfo(Options).@"struct".fields) |field| {
            if (field.type == bool) {
                if (comptime fieldNameStartsWith(field.name, field_prefix)) {
                    if (cliNameMatchesFieldName(field.name[field_prefix.len..], rule_name)) {
                        @field(self, field.name) = value;
                        return true;
                    }
                }
            }
        }
        return false;
    }

    fn cliNameMatchesFieldName(comptime field_name: []const u8, cli_name: []const u8) bool {
        if (cli_name.len != field_name.len) return false;

        comptime var index: usize = 0;
        inline while (index < field_name.len) : (index += 1) {
            const expected = if (field_name[index] == '_') '-' else field_name[index];
            if (cli_name[index] != expected) return false;
        }
        return true;
    }

    fn fieldNameStartsWith(comptime field_name: []const u8, comptime prefix: []const u8) bool {
        @setEvalBranchQuota(10_000);
        if (field_name.len < prefix.len) return false;

        comptime var index: usize = 0;
        inline while (index < prefix.len) : (index += 1) {
            if (field_name[index] != prefix[index]) return false;
        }
        return true;
    }
};

pub const DeprecatedDependenceProfile = enum {
    default,
    ivy,
    insurance,
};

pub const Diagnostic = struct {
    rule_id: []const u8,
    message: []const u8,
    span: ast.Span,
    severity: Severity,
};

pub const Result = struct {
    diagnostics: []Diagnostic,

    pub fn deinit(self: *Result, allocator: Allocator) void {
        for (self.diagnostics) |diagnostic| {
            allocator.free(diagnostic.message);
        }
        allocator.free(self.diagnostics);
    }

    pub fn hasDiagnostics(self: Result) bool {
        return self.diagnostics.len > 0;
    }

    pub fn hasErrors(self: Result) bool {
        for (self.diagnostics) |diagnostic| {
            if (diagnostic.severity == .@"error") return true;
        }
        return false;
    }
};

pub const SourcePosition = struct {
    line: usize,
    column: usize,
};

pub const DiagnosticList = std.ArrayList(Diagnostic);

pub fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    severity: Severity,
    rule_id: []const u8,
    message: []const u8,
    span: ast.Span,
) Allocator.Error!void {
    const owned_message = try allocator.dupe(u8, message);
    errdefer allocator.free(owned_message);

    try diagnostics.append(allocator, .{
        .rule_id = rule_id,
        .message = owned_message,
        .span = span,
        .severity = severity,
    });
}

pub fn addDiagnosticFmt(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    severity: Severity,
    rule_id: []const u8,
    span: ast.Span,
    comptime fmt: []const u8,
    args: anytype,
) Allocator.Error!void {
    const owned_message = try std.fmt.allocPrint(allocator, fmt, args);
    errdefer allocator.free(owned_message);

    try diagnostics.append(allocator, .{
        .rule_id = rule_id,
        .message = owned_message,
        .span = span,
        .severity = severity,
    });
}

pub fn freeDiagnostics(allocator: Allocator, diagnostics: *DiagnosticList) void {
    for (diagnostics.items) |diagnostic| {
        allocator.free(diagnostic.message);
    }
    diagnostics.deinit(allocator);
}

pub fn isKnownGlobal(name: []const u8) bool {
    const globals = [_][]const u8{
        "alert",
        "Array",
        "BigInt",
        "Boolean",
        "Buffer",
        "confirm",
        "Date",
        "Error",
        "Headers",
        "Infinity",
        "Intl",
        "isFinite",
        "isNaN",
        "JSON",
        "Map",
        "Math",
        "NaN",
        "Number",
        "Object",
        "Promise",
        "RegExp",
        "Request",
        "Response",
        "Set",
        "String",
        "Symbol",
        "URL",
        "URLSearchParams",
        "WeakMap",
        "WeakSet",
        "__dirname",
        "__filename",
        "clearInterval",
        "clearTimeout",
        "console",
        "document",
        "exports",
        "fetch",
        "global",
        "globalThis",
        "module",
        "process",
        "prompt",
        "queueMicrotask",
        "require",
        "setInterval",
        "setTimeout",
        "undefined",
        "window",
    };

    for (globals) |global| {
        if (std.mem.eql(u8, name, global)) return true;
    }

    return false;
}

test "Options can enable rules by CLI name" {
    var options = Options.allDisabled();

    try std.testing.expect(!options.no_debugger);
    try std.testing.expect(options.setByCliName("no-debugger", true));
    try std.testing.expect(options.no_debugger);

    try std.testing.expect(!options.typescript_eslint_no_unused_vars);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-unused-vars", true));
    try std.testing.expect(options.typescript_eslint_no_unused_vars);
    try std.testing.expect(!options.no_unused_vars);

    try std.testing.expect(!options.typescript_eslint_no_duplicate_enum_values);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-duplicate-enum-values", true));
    try std.testing.expect(options.typescript_eslint_no_duplicate_enum_values);

    try std.testing.expect(!options.typescript_eslint_no_useless_empty_export);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-useless-empty-export", true));
    try std.testing.expect(options.typescript_eslint_no_useless_empty_export);

    try std.testing.expect(!options.typescript_eslint_no_wrapper_object_types);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-wrapper-object-types", true));
    try std.testing.expect(options.typescript_eslint_no_wrapper_object_types);

    try std.testing.expect(!options.typescript_eslint_no_unnecessary_parameter_property_assignment);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-unnecessary-parameter-property-assignment", true));
    try std.testing.expect(options.typescript_eslint_no_unnecessary_parameter_property_assignment);

    try std.testing.expect(!options.typescript_eslint_no_unsafe_declaration_merging);
    try std.testing.expect(options.setByCliName("@typescript-eslint/no-unsafe-declaration-merging", true));
    try std.testing.expect(options.typescript_eslint_no_unsafe_declaration_merging);

    try std.testing.expect(!options.jsx_a11y_aria_props);
    try std.testing.expect(options.setByCliName("jsx-a11y/aria-props", true));
    try std.testing.expect(options.jsx_a11y_aria_props);

    try std.testing.expect(!options.react_jsx_no_target_blank);
    try std.testing.expect(options.setByCliName("react/jsx-no-target-blank", true));
    try std.testing.expect(options.react_jsx_no_target_blank);

    try std.testing.expect(!options.import_no_duplicates);
    try std.testing.expect(options.setByCliName("import/no-duplicates", true));
    try std.testing.expect(options.import_no_duplicates);

    try std.testing.expect(!options.alipay_ant_no_import_src);
    try std.testing.expect(options.setByCliName("@alipay/ant/no-import-src", true));
    try std.testing.expect(options.alipay_ant_no_import_src);

    try std.testing.expect(!options.alipay_ant_no_phantom_dependencies);
    try std.testing.expect(options.setByCliName("@alipay/ant/no-phantom-dependencies", true));
    try std.testing.expect(options.alipay_ant_no_phantom_dependencies);

    try std.testing.expect(!options.alipay_ant_disallow_typos);
    try std.testing.expect(options.setByCliName("@alipay/ant/disallow-typos", true));
    try std.testing.expect(options.alipay_ant_disallow_typos);

    try std.testing.expect(!options.alipay_spmlint_use_labeled_spm);
    try std.testing.expect(options.setByCliName("@alipay/spmLint/use-labeled-spm", true));
    try std.testing.expect(options.alipay_spmlint_use_labeled_spm);

    try std.testing.expect(!options.alipay_spmlint_valid_manual_click);
    try std.testing.expect(options.setByCliName("@alipay/spmLint/valid-manual-click", true));
    try std.testing.expect(options.alipay_spmlint_valid_manual_click);

    try std.testing.expect(!options.alipay_spmlint_valid_manual_expo);
    try std.testing.expect(options.setByCliName("@alipay/spmLint/valid-manual-expo", true));
    try std.testing.expect(options.alipay_spmlint_valid_manual_expo);

    try std.testing.expect(!options.alipay_spmlint_valid_manual_param);
    try std.testing.expect(options.setByCliName("@alipay/spmLint/valid-manual-param", true));
    try std.testing.expect(options.alipay_spmlint_valid_manual_param);

    try std.testing.expect(!options.alipay_spmlint_valid_manual_pv);
    try std.testing.expect(options.setByCliName("@alipay/spmLint/valid-manual-pv", true));
    try std.testing.expect(options.alipay_spmlint_valid_manual_pv);

    try std.testing.expect(!options.import_default);
    try std.testing.expect(options.setByCliName("import/default", true));
    try std.testing.expect(options.import_default);

    try std.testing.expect(!options.import_export);
    try std.testing.expect(options.setByCliName("import/export", true));
    try std.testing.expect(options.import_export);

    try std.testing.expect(!options.import_named);
    try std.testing.expect(options.setByCliName("import/named", true));
    try std.testing.expect(options.import_named);

    try std.testing.expect(!options.import_namespace);
    try std.testing.expect(options.setByCliName("import/namespace", true));
    try std.testing.expect(options.import_namespace);

    try std.testing.expect(!options.import_no_cycle);
    try std.testing.expect(options.setByCliName("import/no-cycle", true));
    try std.testing.expect(options.import_no_cycle);

    try std.testing.expect(!options.import_no_named_as_default);
    try std.testing.expect(options.setByCliName("import/no-named-as-default", true));
    try std.testing.expect(options.import_no_named_as_default);

    try std.testing.expect(!options.import_no_named_as_default_member);
    try std.testing.expect(options.setByCliName("import/no-named-as-default-member", true));
    try std.testing.expect(options.import_no_named_as_default_member);

    try std.testing.expect(!options.import_no_unresolved);
    try std.testing.expect(options.setByCliName("import/no-unresolved", true));
    try std.testing.expect(options.import_no_unresolved);

    try std.testing.expect(!options.react_default_props_match_prop_types);
    try std.testing.expect(options.setByCliName("react/default-props-match-prop-types", true));
    try std.testing.expect(options.react_default_props_match_prop_types);

    try std.testing.expect(!options.react_prop_types);
    try std.testing.expect(options.setByCliName("react/prop-types", true));
    try std.testing.expect(options.react_prop_types);

    try std.testing.expect(!options.react_no_unused_prop_types);
    try std.testing.expect(options.setByCliName("react/no-unused-prop-types", true));
    try std.testing.expect(options.react_no_unused_prop_types);

    try std.testing.expect(!options.react_hooks_rules_of_hooks);
    try std.testing.expect(options.setByCliName("react-hooks/rules-of-hooks", true));
    try std.testing.expect(options.react_hooks_rules_of_hooks);

    try std.testing.expect(!options.setByCliName("unknown-rule", true));
}

test "Options can apply ESLint-style rule config values" {
    var options = Options{};

    try options.setByRuleConfigValue("no-debugger", .{ .string = "off" });
    try std.testing.expect(!options.no_debugger);

    try options.setByRuleConfigValue("no-debugger", .{ .integer = 2 });
    try std.testing.expect(options.no_debugger);

    var array = std.json.Array.init(std.testing.allocator);
    defer array.deinit();
    try array.append(.{ .string = "warn" });
    try options.setByRuleConfigValue("jsx-a11y/aria-props", .{ .array = array });
    try std.testing.expect(options.jsx_a11y_aria_props);

    try options.setByRuleConfigValue("prettier/prettier", .{ .string = "error" });

    var ivy_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"externalPackages\":{\"moment\":\"dayjs\"}}]",
        .{},
    );
    defer ivy_config.deinit();
    try options.setByRuleConfigValue("@alipay/ant/no-deprecated-dependence", ivy_config.value);
    try std.testing.expectEqual(DeprecatedDependenceProfile.ivy, options.alipay_ant_no_deprecated_dependence_profile);

    var insurance_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"externalPackages\":{\"@alipay/one-bridge\":\"babyfish\"}}]",
        .{},
    );
    defer insurance_config.deinit();
    try options.setByRuleConfigValue("@alipay/ant/no-deprecated-dependence", insurance_config.value);
    try std.testing.expectEqual(DeprecatedDependenceProfile.insurance, options.alipay_ant_no_deprecated_dependence_profile);

    var restricted_disable_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"warn\",\"no-nested-ternary\"]",
        .{},
    );
    defer restricted_disable_config.deinit();
    try options.setByRuleConfigValue("eslint-comments/no-restricted-disable", restricted_disable_config.value);
    try std.testing.expect(options.eslint_comments_no_restricted_disable);
    try std.testing.expect(options.eslint_comments_no_restricted_disable_no_nested_ternary);

    try std.testing.expectError(
        Options.RuleConfigError.UnsupportedRuleConfigValue,
        options.setByRuleConfigValue("no-debugger", .{ .string = "sometimes" }),
    );
    try std.testing.expectError(
        Options.RuleConfigError.UnknownRule,
        options.setByRuleConfigValue("unknown-rule", .{ .string = "off" }),
    );
}
