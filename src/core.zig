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

pub const EqeqeqStyle = enum {
    strict,
    allow_null,
};

pub const CurlyStyle = enum {
    all,
    multi_line,
};

pub const ObjectShorthandStyle = enum {
    always,
    methods,
    properties,
    never,
};

pub const OperatorAssignmentStyle = enum {
    always,
    never,
};

pub const NoCondAssignStyle = enum {
    except_parens,
    always,
};

pub const NoLabelsAllowLoop = enum {
    yes,
    no,
};

pub const NoLabelsAllowSwitch = enum {
    yes,
    no,
};

pub const NoConfusingArrowAllowParens = enum {
    yes,
    no,
};

pub const NoConsoleAllow = struct {
    assert: bool = false,
    clear: bool = false,
    count: bool = false,
    countReset: bool = false,
    debug: bool = false,
    dir: bool = false,
    dirxml: bool = false,
    @"error": bool = false,
    group: bool = false,
    groupCollapsed: bool = false,
    groupEnd: bool = false,
    info: bool = false,
    log: bool = false,
    profile: bool = false,
    profileEnd: bool = false,
    table: bool = false,
    time: bool = false,
    timeEnd: bool = false,
    timeLog: bool = false,
    timeStamp: bool = false,
    trace: bool = false,
    warn: bool = false,

    pub fn contains(self: NoConsoleAllow, name: []const u8) bool {
        inline for (@typeInfo(NoConsoleAllow).@"struct".fields) |field| {
            if (std.mem.eql(u8, field.name, name)) return @field(self, field.name);
        }
        return false;
    }

    pub fn enable(self: *NoConsoleAllow, name: []const u8) bool {
        inline for (@typeInfo(NoConsoleAllow).@"struct".fields) |field| {
            if (std.mem.eql(u8, field.name, name)) {
                @field(self, field.name) = true;
                return true;
            }
        }
        return false;
    }
};

pub const NoEmptyAllowEmptyCatch = enum {
    yes,
    no,
};

pub const NoEmptyFunctionAllow = struct {
    functions: bool = false,
    arrowFunctions: bool = false,
    generatorFunctions: bool = false,
    asyncFunctions: bool = false,
    methods: bool = false,
    generatorMethods: bool = false,
    asyncMethods: bool = false,
    getters: bool = false,
    setters: bool = false,
    constructors: bool = false,

    pub fn contains(self: NoEmptyFunctionAllow, name: []const u8) bool {
        inline for (@typeInfo(NoEmptyFunctionAllow).@"struct".fields) |field| {
            if (std.mem.eql(u8, field.name, name)) return @field(self, field.name);
        }
        return false;
    }

    pub fn enable(self: *NoEmptyFunctionAllow, name: []const u8) bool {
        inline for (@typeInfo(NoEmptyFunctionAllow).@"struct".fields) |field| {
            if (std.mem.eql(u8, field.name, name)) {
                @field(self, field.name) = true;
                return true;
            }
        }
        return false;
    }
};

pub const NoFallthroughAllowEmptyCase = enum {
    yes,
    no,
};

pub const NoInvalidRegexpAllowConstructorFlags = struct {
    flags: [256]bool = [_]bool{false} ** 256,

    pub fn contains(self: NoInvalidRegexpAllowConstructorFlags, flag: u8) bool {
        return self.flags[flag];
    }

    pub fn enable(self: *NoInvalidRegexpAllowConstructorFlags, flag: []const u8) bool {
        if (flag.len != 1) return false;
        self.flags[flag[0]] = true;
        return true;
    }
};

pub const NoMultiSpacesIgnoreEOLComments = enum {
    yes,
    no,
};

pub const NoReturnAssignStyle = enum {
    except_parens,
    always,
};

pub const RadixStyle = enum {
    always,
    as_needed,
};

pub const NoSequencesAllowInParentheses = enum {
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
    slash,
    slash_asterisk,
};

pub const no_warning_comments_default_terms = [_][]const u8{
    "todo",
    "fixme",
    "xxx",
};

pub const max_no_warning_comments_terms = 32;
pub const max_no_warning_comments_term_len = 128;

pub const NoWarningCommentsTermsError = error{
    EmptyNoWarningCommentsTerm,
    TooManyNoWarningCommentsTerms,
    NoWarningCommentsTermTooLong,
};

pub const NoWarningCommentsTerms = struct {
    custom: bool = false,
    count: usize = 0,
    lengths: [max_no_warning_comments_terms]usize = undefined,
    storage: [max_no_warning_comments_terms][max_no_warning_comments_term_len]u8 = undefined,

    pub fn len(self: *const NoWarningCommentsTerms) usize {
        return if (self.custom) self.count else no_warning_comments_default_terms.len;
    }

    pub fn at(self: *const NoWarningCommentsTerms, index: usize) []const u8 {
        if (!self.custom) return no_warning_comments_default_terms[index];
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn set(self: *NoWarningCommentsTerms, terms: []const []const u8) NoWarningCommentsTermsError!void {
        self.custom = true;
        self.count = 0;
        for (terms) |term| try self.append(term);
    }

    pub fn append(self: *NoWarningCommentsTerms, term: []const u8) NoWarningCommentsTermsError!void {
        if (term.len == 0) return error.EmptyNoWarningCommentsTerm;
        if (self.count >= max_no_warning_comments_terms) return error.TooManyNoWarningCommentsTerms;
        if (term.len > max_no_warning_comments_term_len) return error.NoWarningCommentsTermTooLong;

        self.custom = true;
        @memcpy(self.storage[self.count][0..term.len], term);
        self.lengths[self.count] = term.len;
        self.count += 1;
    }
};

pub const SpacedCommentStyle = enum {
    always,
    never,
};

pub const NoVoidAllowAsStatement = enum {
    yes,
    no,
};

pub const NoImplicitCoercionBoolean = enum {
    yes,
    no,
};

pub const NoImplicitCoercionNumber = enum {
    yes,
    no,
};

pub const NoImplicitCoercionString = enum {
    yes,
    no,
};

pub const NoPlusplusAllowForLoopAfterthoughts = enum {
    yes,
    no,
};

pub const NoRedeclareBuiltinGlobals = enum {
    yes,
    no,
};

pub const NoUnusedExpressionsAllowShortCircuit = enum {
    yes,
    no,
};

pub const NoUnusedExpressionsAllowTernary = enum {
    yes,
    no,
};

pub const NoUnusedExpressionsAllowTaggedTemplates = enum {
    yes,
    no,
};

pub const NoUseBeforeDefineCheck = enum {
    yes,
    no,
};

pub const NoUnusedVarsArgs = enum {
    none,
    after_used,
    all,
};

pub const NoUnusedVarsCaughtErrors = enum {
    none,
    all,
};

pub const NoParamReassignProps = enum {
    yes,
    no,
};

pub const max_no_param_reassign_ignored_names = 32;
pub const max_no_param_reassign_ignored_name_len = 128;

pub const NoParamReassignIgnoredNamesError = error{
    EmptyNoParamReassignIgnoredName,
    TooManyNoParamReassignIgnoredNames,
    NoParamReassignIgnoredNameTooLong,
};

pub const NoParamReassignIgnoredNames = struct {
    count: usize = 0,
    lengths: [max_no_param_reassign_ignored_names]usize = undefined,
    storage: [max_no_param_reassign_ignored_names][max_no_param_reassign_ignored_name_len]u8 = undefined,

    pub fn contains(self: *const NoParamReassignIgnoredNames, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const NoParamReassignIgnoredNames, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *NoParamReassignIgnoredNames, name: []const u8) NoParamReassignIgnoredNamesError!void {
        if (name.len == 0) return error.EmptyNoParamReassignIgnoredName;
        if (self.count >= max_no_param_reassign_ignored_names) return error.TooManyNoParamReassignIgnoredNames;
        if (name.len > max_no_param_reassign_ignored_name_len) return error.NoParamReassignIgnoredNameTooLong;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const max_no_shadow_allow_names = 32;
pub const max_no_shadow_allow_name_len = 128;

pub const NoShadowAllowNamesError = error{
    EmptyNoShadowAllowName,
    TooManyNoShadowAllowNames,
    NoShadowAllowNameTooLong,
};

pub const NoShadowAllowNames = struct {
    count: usize = 0,
    lengths: [max_no_shadow_allow_names]usize = undefined,
    storage: [max_no_shadow_allow_names][max_no_shadow_allow_name_len]u8 = undefined,

    pub fn contains(self: *const NoShadowAllowNames, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const NoShadowAllowNames, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *NoShadowAllowNames, name: []const u8) NoShadowAllowNamesError!void {
        if (name.len == 0) return error.EmptyNoShadowAllowName;
        if (self.count >= max_no_shadow_allow_names) return error.TooManyNoShadowAllowNames;
        if (name.len > max_no_shadow_allow_name_len) return error.NoShadowAllowNameTooLong;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const max_new_cap_exception_names = 32;
pub const max_new_cap_exception_name_len = 128;

pub const NewCapExceptionNamesError = error{
    EmptyNewCapExceptionName,
    TooManyNewCapExceptionNames,
    NewCapExceptionNameTooLong,
};

pub const NewCapExceptionNames = struct {
    count: usize = 0,
    lengths: [max_new_cap_exception_names]usize = undefined,
    storage: [max_new_cap_exception_names][max_new_cap_exception_name_len]u8 = undefined,

    pub fn contains(self: *const NewCapExceptionNames, name: []const u8) bool {
        for (0..self.count) |index| {
            if (std.mem.eql(u8, self.at(index), name)) return true;
        }
        return false;
    }

    pub fn at(self: *const NewCapExceptionNames, index: usize) []const u8 {
        return self.storage[index][0..self.lengths[index]];
    }

    pub fn append(self: *NewCapExceptionNames, name: []const u8) NewCapExceptionNamesError!void {
        if (name.len == 0) return error.EmptyNewCapExceptionName;
        if (self.count >= max_new_cap_exception_names) return error.TooManyNewCapExceptionNames;
        if (name.len > max_new_cap_exception_name_len) return error.NewCapExceptionNameTooLong;

        @memcpy(self.storage[self.count][0..name.len], name);
        self.lengths[self.count] = name.len;
        self.count += 1;
    }
};

pub const NoUselessComputedKeyEnforceForClassMembers = enum {
    yes,
    no,
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

pub const AccessorPairsSetWithoutGet = enum {
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

pub const LogicalAssignmentOperatorsStyle = enum {
    always,
    never,
};

pub const FuncNamesStyle = enum {
    always,
    as_needed,
    never,
};

pub const FuncNameMatchingStyle = enum {
    always,
    never,
};

pub const NoConstantConditionCheckLoops = enum {
    all,
    all_except_while_true,
    none,
};

pub const YodaStyle = enum {
    never,
    always,
};

pub const TypescriptEslintMethodSignatureStyle = enum {
    property,
    method,
};

pub const TypescriptEslintClassLiteralPropertyStyle = enum {
    fields,
    getters,
};

pub const PreferConstDestructuring = enum {
    any,
    all,
};

pub const ArrayCallbackReturnAllowImplicit = enum {
    yes,
    no,
};

pub const ArrayCallbackReturnCheckForEach = enum {
    yes,
    no,
};

pub const ArrayCallbackReturnAllowVoid = enum {
    yes,
    no,
};

pub const CapitalizedCommentsMode = enum {
    always,
    never,
};

pub const CapitalizedCommentsIgnoreInlineComments = enum {
    yes,
    no,
};

pub const DotNotationAllowKeywords = enum {
    yes,
    no,
};

pub const Options = struct {
    accessor_pairs: bool = true,
    accessor_pairs_get_without_set: AccessorPairsGetWithoutSet = .no,
    accessor_pairs_set_without_get: AccessorPairsSetWithoutGet = .yes,
    array_callback_return: bool = true,
    array_callback_return_allow_implicit: ArrayCallbackReturnAllowImplicit = .no,
    array_callback_return_check_for_each: ArrayCallbackReturnCheckForEach = .no,
    array_callback_return_allow_void: ArrayCallbackReturnAllowVoid = .no,
    block_scoped_var: bool = true,
    capitalized_comments: bool = true,
    capitalized_comments_mode: CapitalizedCommentsMode = .always,
    capitalized_comments_ignore_inline_comments: CapitalizedCommentsIgnoreInlineComments = .no,
    consistent_return: bool = true,
    consistent_return_treat_undefined_as_unspecified: bool = false,
    constructor_super: bool = true,
    curly: bool = true,
    curly_style: CurlyStyle = .all,
    dot_notation: bool = true,
    dot_notation_allow_keywords: DotNotationAllowKeywords = .yes,
    typescript_eslint_dot_notation: bool = true,
    default_case: bool = true,
    default_case_last: bool = true,
    default_param_last: bool = true,
    eol_last: bool = true,
    eslint_comments_no_restricted_disable: bool = true,
    eslint_comments_no_restricted_disable_no_nested_ternary: bool = false,
    for_direction: bool = true,
    func_name_matching: bool = true,
    func_name_matching_style: FuncNameMatchingStyle = .always,
    func_names: bool = true,
    func_names_style: FuncNamesStyle = .always,
    getter_return: bool = true,
    grouped_accessor_pairs: bool = true,
    grouped_accessor_pairs_style: GroupedAccessorPairsStyle = .any_order,
    guard_for_in: bool = true,
    linebreak_style: bool = true,
    logical_assignment_operators: bool = true,
    logical_assignment_operators_style: LogicalAssignmentOperatorsStyle = .always,
    logical_assignment_operators_enforce_for_if_statements: LogicalAssignmentOperatorsEnforceForIfStatements = .no,
    new_cap: bool = true,
    new_cap_new_is_cap: bool = true,
    new_cap_cap_is_new: bool = true,
    new_cap_properties: bool = true,
    new_cap_new_is_cap_exceptions: NewCapExceptionNames = .{},
    new_cap_cap_is_new_exceptions: NewCapExceptionNames = .{},
    new_parens: bool = true,
    no_async_promise_executor: bool = true,
    no_array_constructor: bool = true,
    no_await_in_loop: bool = true,
    no_alert: bool = true,
    no_bitwise: bool = true,
    no_bitwise_allow_bitwise_and: bool = false,
    no_bitwise_allow_bitwise_or: bool = false,
    no_bitwise_allow_bitwise_xor: bool = false,
    no_bitwise_allow_bitwise_not: bool = false,
    no_bitwise_allow_left_shift: bool = false,
    no_bitwise_allow_right_shift: bool = false,
    no_bitwise_allow_unsigned_right_shift: bool = false,
    no_bitwise_int32_hint: bool = false,
    no_buffer_constructor: bool = true,
    no_caller: bool = true,
    no_case_declarations: bool = true,
    no_class_assign: bool = true,
    no_confusing_arrow: bool = true,
    no_confusing_arrow_allow_parens: NoConfusingArrowAllowParens = .yes,
    no_cond_assign: bool = true,
    no_cond_assign_style: NoCondAssignStyle = .except_parens,
    no_compare_neg_zero: bool = true,
    no_constant_condition: bool = true,
    no_constant_condition_check_loops: NoConstantConditionCheckLoops = .all_except_while_true,
    no_const_assign: bool = true,
    no_control_regex: bool = true,
    no_console: bool = true,
    no_console_allow: NoConsoleAllow = .{},
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
    no_empty_allow_empty_catch: NoEmptyAllowEmptyCatch = .no,
    no_empty_block_statements: bool = true,
    no_empty_character_class: bool = true,
    no_empty_function: bool = true,
    no_empty_function_allow: NoEmptyFunctionAllow = .{},
    no_empty_pattern: bool = true,
    no_empty_static_block: bool = true,
    no_else_return: bool = true,
    no_else_return_allow_else_if: bool = true,
    no_eq_null: bool = true,
    no_eval: bool = true,
    no_ex_assign: bool = true,
    no_extend_native: bool = true,
    no_extra_bind: bool = true,
    no_extra_label: bool = true,
    no_extra_semi: bool = true,
    no_extra_boolean_cast: bool = true,
    no_extra_boolean_cast_enforce_for_inner_expressions: bool = false,
    no_floating_decimal: bool = true,
    no_fallthrough: bool = true,
    no_fallthrough_allow_empty_case: NoFallthroughAllowEmptyCase = .no,
    no_for_in: bool = true,
    no_func_assign: bool = true,
    no_global_assign: bool = true,
    no_global_is_finite: bool = true,
    no_global_is_nan: bool = true,
    no_implicit_coercion: bool = true,
    no_implicit_coercion_boolean: NoImplicitCoercionBoolean = .yes,
    no_implicit_coercion_number: NoImplicitCoercionNumber = .yes,
    no_implicit_coercion_string: NoImplicitCoercionString = .yes,
    no_implicit_coercion_allow_double_negation: bool = false,
    no_implicit_coercion_allow_bitwise_not: bool = false,
    no_implicit_coercion_allow_unary_plus: bool = false,
    no_implicit_coercion_allow_multiply: bool = false,
    no_implicit_coercion_allow_subtract: bool = false,
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
    alipay_ant_prefer_managed_resource: bool = true,
    alipay_ant_prefer_safe_image_renderer: bool = true,
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
    no_invalid_regexp_allow_constructor_flags: NoInvalidRegexpAllowConstructorFlags = .{},
    no_irregular_whitespace: bool = true,
    no_inline_comments: bool = true,
    no_inner_declarations: bool = true,
    no_iterator: bool = true,
    no_label_var: bool = true,
    no_labels: bool = true,
    no_labels_allow_loop: NoLabelsAllowLoop = .no,
    no_labels_allow_switch: NoLabelsAllowSwitch = .no,
    no_lone_blocks: bool = true,
    no_lonely_if: bool = true,
    no_loop_func: bool = true,
    no_loss_of_precision: bool = true,
    no_multi_str: bool = true,
    no_multi_assign: bool = true,
    no_multi_spaces: bool = true,
    no_multi_spaces_ignore_eol_comments: NoMultiSpacesIgnoreEOLComments = .no,
    no_mixed_spaces_and_tabs: bool = true,
    no_misleading_character_class: bool = true,
    no_multiple_empty_lines: bool = true,
    no_multiple_empty_lines_max: usize = 2,
    no_multiple_empty_lines_max_bof: ?usize = null,
    no_multiple_empty_lines_max_eof: ?usize = null,
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
    no_param_reassign_props: NoParamReassignProps = .no,
    no_param_reassign_ignore_property_modifications_for: NoParamReassignIgnoredNames = .{},
    no_path_concat: bool = true,
    no_plusplus: bool = true,
    no_plusplus_allow_for_loop_afterthoughts: NoPlusplusAllowForLoopAfterthoughts = .no,
    no_promise_executor_return: bool = true,
    no_proto: bool = true,
    no_process_env: bool = true,
    no_process_exit: bool = true,
    no_prototype_builtins: bool = true,
    no_redeclare: bool = true,
    no_redeclare_builtin_globals: NoRedeclareBuiltinGlobals = .no,
    no_regex_spaces: bool = true,
    no_return_await: bool = true,
    no_return_assign: bool = true,
    no_return_assign_style: NoReturnAssignStyle = .except_parens,
    no_useless_return: bool = true,
    no_script_url: bool = true,
    no_self_assign: bool = true,
    no_self_compare: bool = true,
    no_setter_return: bool = true,
    no_shadow: bool = true,
    no_shadow_allow: NoShadowAllowNames = .{},
    no_shadow_builtin_globals: bool = false,
    no_shadow_restricted_names: bool = true,
    no_sequences: bool = true,
    no_sequences_allow_in_parentheses: NoSequencesAllowInParentheses = .yes,
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
    no_unneeded_ternary_default_assignment: bool = true,
    no_unused_labels: bool = true,
    no_unsafe_finally: bool = true,
    no_unsafe_negation: bool = true,
    no_useless_computed_key: bool = true,
    no_useless_computed_key_enforce_for_class_members: NoUselessComputedKeyEnforceForClassMembers = .yes,
    no_useless_call: bool = true,
    no_useless_concat: bool = true,
    no_useless_constructor: bool = true,
    no_useless_catch: bool = true,
    no_useless_escape: bool = true,
    no_useless_rename: bool = true,
    no_unused_expressions: bool = true,
    no_unused_expressions_allow_short_circuit: NoUnusedExpressionsAllowShortCircuit = .no,
    no_unused_expressions_allow_ternary: NoUnusedExpressionsAllowTernary = .no,
    no_unused_expressions_allow_tagged_templates: NoUnusedExpressionsAllowTaggedTemplates = .no,
    typescript_eslint_no_unused_expressions: bool = true,
    no_warning_comments: bool = true,
    no_warning_comments_location: NoWarningCommentsLocation = .start,
    no_warning_comments_decoration: NoWarningCommentsDecoration = .none,
    no_warning_comments_terms: NoWarningCommentsTerms = .{},
    no_void: bool = true,
    no_void_allow_as_statement: NoVoidAllowAsStatement = .no,
    no_with: bool = true,
    no_var: bool = true,
    object_shorthand: bool = true,
    object_shorthand_style: ObjectShorthandStyle = .always,
    object_shorthand_avoid_quotes: bool = false,
    one_var: bool = true,
    operator_assignment: bool = true,
    operator_assignment_style: OperatorAssignmentStyle = .always,
    eqeqeq: bool = true,
    eqeqeq_style: EqeqeqStyle = .strict,
    use_isnan: bool = true,
    no_unused_vars: bool = true,
    no_unused_vars_args: NoUnusedVarsArgs = .none,
    no_unused_vars_caught_errors: NoUnusedVarsCaughtErrors = .all,
    no_unused_vars_ignore_rest_siblings: bool = false,
    no_use_before_define: bool = true,
    no_use_before_define_check_functions: NoUseBeforeDefineCheck = .yes,
    no_use_before_define_check_classes: NoUseBeforeDefineCheck = .yes,
    no_undef: bool = true,
    no_undef_typeof: bool = false,
    prefer_const: bool = true,
    prefer_const_destructuring: PreferConstDestructuring = .any,
    prefer_exponentiation_operator: bool = true,
    prefer_numeric_literals: bool = true,
    prefer_object_has_own: bool = true,
    prefer_promise_reject_errors: bool = true,
    prefer_destructuring: bool = true,
    prefer_destructuring_variable_declarator_array: bool = true,
    prefer_destructuring_variable_declarator_object: bool = true,
    prefer_destructuring_assignment_expression_array: bool = true,
    prefer_destructuring_assignment_expression_object: bool = true,
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
    radix_style: RadixStyle = .always,
    require_await: bool = true,
    require_atomic_updates: bool = true,
    require_yield: bool = true,
    spaced_comment: bool = true,
    spaced_comment_style: SpacedCommentStyle = .always,
    symbol_description: bool = true,
    typescript_eslint_adjacent_overload_signatures: bool = true,
    typescript_eslint_array_type: bool = true,
    typescript_eslint_class_literal_property_style: bool = true,
    typescript_eslint_class_literal_property_style_style: TypescriptEslintClassLiteralPropertyStyle = .fields,
    typescript_eslint_consistent_type_assertions: bool = true,
    typescript_eslint_consistent_type_definitions: bool = true,
    typescript_eslint_no_array_constructor: bool = true,
    typescript_eslint_ban_types: bool = true,
    typescript_eslint_ban_ts_comment: bool = true,
    typescript_eslint_ban_tslint_comment: bool = true,
    typescript_eslint_explicit_member_accessibility: bool = true,
    typescript_eslint_member_ordering: bool = true,
    typescript_eslint_method_signature_style: bool = true,
    typescript_eslint_method_signature_style_style: TypescriptEslintMethodSignatureStyle = .property,
    typescript_eslint_no_confusing_non_null_assertion: bool = true,
    typescript_eslint_no_empty_function: bool = true,
    typescript_eslint_no_empty_function_allow: NoEmptyFunctionAllow = .{},
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
    typescript_eslint_no_shadow_allow: NoShadowAllowNames = .{},
    typescript_eslint_no_shadow_builtin_globals: bool = false,
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
    typescript_eslint_no_unused_vars_args: NoUnusedVarsArgs = .after_used,
    typescript_eslint_no_unused_vars_caught_errors: NoUnusedVarsCaughtErrors = .all,
    typescript_eslint_no_unused_vars_ignore_rest_siblings: bool = true,
    typescript_eslint_no_use_before_define: bool = true,
    typescript_eslint_no_use_before_define_check_functions: NoUseBeforeDefineCheck = .no,
    typescript_eslint_no_use_before_define_check_classes: NoUseBeforeDefineCheck = .yes,
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
    yoda_style: YodaStyle = .never,
    yoda_only_equality: bool = false,

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
        if (std.mem.eql(u8, cli_name, "accessor-pairs")) {
            self.accessor_pairs_get_without_set = try accessorPairsGetWithoutSetFromConfig(value);
            self.accessor_pairs_set_without_get = try accessorPairsSetWithoutGetFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "array-callback-return")) {
            self.array_callback_return_allow_implicit = try arrayCallbackReturnAllowImplicitFromConfig(value);
            self.array_callback_return_check_for_each = try arrayCallbackReturnCheckForEachFromConfig(value);
            self.array_callback_return_allow_void = try arrayCallbackReturnAllowVoidFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "capitalized-comments")) {
            self.capitalized_comments_mode = try capitalizedCommentsModeFromConfig(value);
            self.capitalized_comments_ignore_inline_comments = try capitalizedCommentsIgnoreInlineCommentsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "consistent-return")) {
            self.consistent_return_treat_undefined_as_unspecified = try consistentReturnTreatUndefinedAsUnspecifiedFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "curly")) {
            self.curly_style = try curlyStyleFromConfig(value);
        }
        if (enabled and (std.mem.eql(u8, cli_name, "dot-notation") or std.mem.eql(u8, cli_name, "@typescript-eslint/dot-notation"))) {
            self.dot_notation_allow_keywords = try dotNotationAllowKeywordsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "eslint-comments/no-restricted-disable")) {
            self.eslint_comments_no_restricted_disable_no_nested_ternary = noRestrictedDisableRestrictsNoNestedTernary(value);
        }
        if (std.mem.eql(u8, cli_name, "func-name-matching")) {
            self.func_name_matching_style = try funcNameMatchingStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "func-names")) {
            self.func_names_style = try funcNamesStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "grouped-accessor-pairs")) {
            self.grouped_accessor_pairs_style = try groupedAccessorPairsStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "eqeqeq")) {
            self.eqeqeq_style = try eqeqeqStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "logical-assignment-operators")) {
            self.logical_assignment_operators_style = try logicalAssignmentOperatorsStyleFromConfig(value);
            self.logical_assignment_operators_enforce_for_if_statements = try logicalAssignmentOperatorsEnforceForIfStatementsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "new-cap")) {
            self.new_cap_new_is_cap = try newCapBoolOptionFromConfig(value, "newIsCap", true);
            self.new_cap_cap_is_new = try newCapBoolOptionFromConfig(value, "capIsNew", true);
            self.new_cap_properties = try newCapBoolOptionFromConfig(value, "properties", true);
            self.new_cap_new_is_cap_exceptions = try newCapExceptionNamesFromConfig(value, "newIsCapExceptions");
            self.new_cap_cap_is_new_exceptions = try newCapExceptionNamesFromConfig(value, "capIsNewExceptions");
        }
        if (std.mem.eql(u8, cli_name, "no-bitwise")) {
            self.no_bitwise_allow_bitwise_and = try noBitwiseAllowFromConfig(value, "&");
            self.no_bitwise_allow_bitwise_or = try noBitwiseAllowFromConfig(value, "|");
            self.no_bitwise_allow_bitwise_xor = try noBitwiseAllowFromConfig(value, "^");
            self.no_bitwise_allow_bitwise_not = try noBitwiseAllowFromConfig(value, "~");
            self.no_bitwise_allow_left_shift = try noBitwiseAllowFromConfig(value, "<<");
            self.no_bitwise_allow_right_shift = try noBitwiseAllowFromConfig(value, ">>");
            self.no_bitwise_allow_unsigned_right_shift = try noBitwiseAllowFromConfig(value, ">>>");
            self.no_bitwise_int32_hint = try noBitwiseInt32HintFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-console")) {
            self.no_console_allow = try noConsoleAllowFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-cond-assign")) {
            self.no_cond_assign_style = try noCondAssignStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-constant-condition")) {
            self.no_constant_condition_check_loops = try noConstantConditionCheckLoopsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-confusing-arrow")) {
            self.no_confusing_arrow_allow_parens = try noConfusingArrowAllowParensFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-empty")) {
            self.no_empty_allow_empty_catch = try noEmptyAllowEmptyCatchFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-empty-function")) {
            self.no_empty_function_allow = try noEmptyFunctionAllowFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-empty-function")) {
            self.typescript_eslint_no_empty_function_allow = try noEmptyFunctionAllowFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-else-return")) {
            self.no_else_return_allow_else_if = try noElseReturnAllowElseIfFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-extra-boolean-cast")) {
            self.no_extra_boolean_cast_enforce_for_inner_expressions = try noExtraBooleanCastEnforceForInnerExpressionsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-fallthrough")) {
            self.no_fallthrough_allow_empty_case = try noFallthroughAllowEmptyCaseFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-implicit-coercion")) {
            self.no_implicit_coercion_boolean = try noImplicitCoercionBooleanFromConfig(value);
            self.no_implicit_coercion_number = try noImplicitCoercionNumberFromConfig(value);
            self.no_implicit_coercion_string = try noImplicitCoercionStringFromConfig(value);
            self.no_implicit_coercion_allow_double_negation = try noImplicitCoercionAllowFromConfig(value, "!!");
            self.no_implicit_coercion_allow_bitwise_not = try noImplicitCoercionAllowFromConfig(value, "~");
            self.no_implicit_coercion_allow_unary_plus = try noImplicitCoercionAllowFromConfig(value, "+");
            self.no_implicit_coercion_allow_multiply = try noImplicitCoercionAllowFromConfig(value, "*");
            self.no_implicit_coercion_allow_subtract = try noImplicitCoercionAllowFromConfig(value, "-");
        }
        if (std.mem.eql(u8, cli_name, "no-invalid-regexp")) {
            self.no_invalid_regexp_allow_constructor_flags = try noInvalidRegexpAllowConstructorFlagsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-labels")) {
            self.no_labels_allow_loop = try noLabelsAllowLoopFromConfig(value);
            self.no_labels_allow_switch = try noLabelsAllowSwitchFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-multi-spaces")) {
            self.no_multi_spaces_ignore_eol_comments = try noMultiSpacesIgnoreEOLCommentsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-multiple-empty-lines")) {
            self.no_multiple_empty_lines_max = try noMultipleEmptyLinesMaxFromConfig(value);
            self.no_multiple_empty_lines_max_bof = try noMultipleEmptyLinesMaxBofFromConfig(value);
            self.no_multiple_empty_lines_max_eof = try noMultipleEmptyLinesMaxEofFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-param-reassign")) {
            self.no_param_reassign_props = try noParamReassignPropsFromConfig(value);
            self.no_param_reassign_ignore_property_modifications_for = try noParamReassignIgnoredNamesFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-redeclare")) {
            self.no_redeclare_builtin_globals = try noRedeclareBuiltinGlobalsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-shadow")) {
            self.no_shadow_allow = try noShadowAllowFromConfig(value);
            self.no_shadow_builtin_globals = try noShadowBuiltinGlobalsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-underscore-dangle")) {
            self.no_underscore_dangle_allow_after_this = try noUnderscoreDangleBoolOptionFromConfig(value, "allowAfterThis", false);
            self.no_underscore_dangle_allow_after_super = try noUnderscoreDangleBoolOptionFromConfig(value, "allowAfterSuper", false);
            self.no_underscore_dangle_allow_after_this_constructor = try noUnderscoreDangleBoolOptionFromConfig(value, "allowAfterThisConstructor", false);
            self.no_underscore_dangle_allow_function_params = if (try noUnderscoreDangleBoolOptionFromConfig(value, "allowFunctionParams", true)) .yes else .no;
            self.no_underscore_dangle_allow_in_array_destructuring = if (try noUnderscoreDangleBoolOptionFromConfig(value, "allowInArrayDestructuring", true)) .yes else .no;
            self.no_underscore_dangle_allow_in_object_destructuring = if (try noUnderscoreDangleBoolOptionFromConfig(value, "allowInObjectDestructuring", true)) .yes else .no;
            self.no_underscore_dangle_enforce_in_method_names = try noUnderscoreDangleBoolOptionFromConfig(value, "enforceInMethodNames", false);
            self.no_underscore_dangle_enforce_in_class_fields = try noUnderscoreDangleBoolOptionFromConfig(value, "enforceInClassFields", false);
        }
        if (std.mem.eql(u8, cli_name, "no-plusplus")) {
            self.no_plusplus_allow_for_loop_afterthoughts = try noPlusplusAllowForLoopAfterthoughtsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "prefer-const")) {
            self.prefer_const_destructuring = try preferConstDestructuringFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "prefer-destructuring")) {
            self.prefer_destructuring_variable_declarator_array = try preferDestructuringOptionFromConfig(value, "VariableDeclarator", "array", true);
            self.prefer_destructuring_variable_declarator_object = try preferDestructuringOptionFromConfig(value, "VariableDeclarator", "object", true);
            self.prefer_destructuring_assignment_expression_array = try preferDestructuringOptionFromConfig(value, "AssignmentExpression", "array", true);
            self.prefer_destructuring_assignment_expression_object = try preferDestructuringOptionFromConfig(value, "AssignmentExpression", "object", true);
        }
        if (std.mem.eql(u8, cli_name, "radix")) {
            self.radix_style = try radixStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-return-assign")) {
            self.no_return_assign_style = try noReturnAssignStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-sequences")) {
            self.no_sequences_allow_in_parentheses = try noSequencesAllowInParenthesesFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-useless-computed-key")) {
            self.no_useless_computed_key_enforce_for_class_members = try noUselessComputedKeyEnforceForClassMembersFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-unused-expressions")) {
            self.no_unused_expressions_allow_short_circuit = try noUnusedExpressionsAllowShortCircuitFromConfig(value);
            self.no_unused_expressions_allow_ternary = try noUnusedExpressionsAllowTernaryFromConfig(value);
            self.no_unused_expressions_allow_tagged_templates = try noUnusedExpressionsAllowTaggedTemplatesFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-unused-vars")) {
            self.no_unused_vars_args = try noUnusedVarsArgsFromConfig(value, .none);
            self.no_unused_vars_caught_errors = try noUnusedVarsCaughtErrorsFromConfig(value, .all);
            self.no_unused_vars_ignore_rest_siblings = try noUnusedVarsIgnoreRestSiblingsFromConfig(value, false);
        }
        if (std.mem.eql(u8, cli_name, "no-use-before-define")) {
            self.no_use_before_define_check_functions = try noUseBeforeDefineCheckFromConfig(value, "functions", true);
            self.no_use_before_define_check_classes = try noUseBeforeDefineCheckFromConfig(value, "classes", true);
        }
        if (std.mem.eql(u8, cli_name, "object-shorthand")) {
            self.object_shorthand_style = try objectShorthandStyleFromConfig(value);
            self.object_shorthand_avoid_quotes = try objectShorthandAvoidQuotesFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "operator-assignment")) {
            self.operator_assignment_style = try operatorAssignmentStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/class-literal-property-style")) {
            self.typescript_eslint_class_literal_property_style_style = try typescriptEslintClassLiteralPropertyStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-shadow")) {
            self.typescript_eslint_no_shadow_allow = try noShadowAllowFromConfig(value);
            self.typescript_eslint_no_shadow_builtin_globals = try noShadowBuiltinGlobalsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/method-signature-style")) {
            self.typescript_eslint_method_signature_style_style = try typescriptEslintMethodSignatureStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-unused-vars")) {
            self.typescript_eslint_no_unused_vars_args = try noUnusedVarsArgsFromConfig(value, .after_used);
            self.typescript_eslint_no_unused_vars_caught_errors = try noUnusedVarsCaughtErrorsFromConfig(value, .all);
            self.typescript_eslint_no_unused_vars_ignore_rest_siblings = try noUnusedVarsIgnoreRestSiblingsFromConfig(value, true);
        }
        if (std.mem.eql(u8, cli_name, "no-undef")) {
            self.no_undef_typeof = try noUndefTypeofFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-unneeded-ternary")) {
            self.no_unneeded_ternary_default_assignment = try noUnneededTernaryDefaultAssignmentFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "@typescript-eslint/no-use-before-define")) {
            self.typescript_eslint_no_use_before_define_check_functions = try noUseBeforeDefineCheckFromConfig(value, "functions", false);
            self.typescript_eslint_no_use_before_define_check_classes = try noUseBeforeDefineCheckFromConfig(value, "classes", true);
        }
        if (std.mem.eql(u8, cli_name, "no-void")) {
            self.no_void_allow_as_statement = try noVoidAllowAsStatementFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "no-warning-comments")) {
            self.no_warning_comments_location = try noWarningCommentsLocationFromConfig(value);
            self.no_warning_comments_decoration = try noWarningCommentsDecorationFromConfig(value);
            self.no_warning_comments_terms = try noWarningCommentsTermsFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "spaced-comment")) {
            self.spaced_comment_style = try spacedCommentStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "wrap-iife")) {
            self.wrap_iife_style = try wrapIifeStyleFromConfig(value);
        }
        if (std.mem.eql(u8, cli_name, "yoda")) {
            self.yoda_style = try yodaStyleFromConfig(value);
            self.yoda_only_equality = try yodaOnlyEqualityFromConfig(value);
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

    fn curlyStyleFromConfig(value: std.json.Value) RuleConfigError!CurlyStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .all,
        };
        if (items.len < 2) return .all;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "all")) return .all;
        if (std.mem.eql(u8, style, "multi-line")) return .multi_line;
        return error.UnsupportedRuleConfigValue;
    }

    fn eqeqeqStyleFromConfig(value: std.json.Value) RuleConfigError!EqeqeqStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .strict,
        };
        if (items.len < 2) return .strict;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .strict;
        if (std.mem.eql(u8, style, "allow-null")) return .allow_null;
        return error.UnsupportedRuleConfigValue;
    }

    fn consistentReturnTreatUndefinedAsUnspecifiedFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("treatUndefinedAsUnspecified") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn accessorPairsGetWithoutSetFromConfig(value: std.json.Value) RuleConfigError!AccessorPairsGetWithoutSet {
        const enabled = try accessorPairsOptionFromConfig(value, "getWithoutSet", false);
        return if (enabled) .yes else .no;
    }

    fn accessorPairsSetWithoutGetFromConfig(value: std.json.Value) RuleConfigError!AccessorPairsSetWithoutGet {
        const enabled = try accessorPairsOptionFromConfig(value, "setWithoutGet", true);
        return if (enabled) .yes else .no;
    }

    fn accessorPairsOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn arrayCallbackReturnAllowImplicitFromConfig(value: std.json.Value) RuleConfigError!ArrayCallbackReturnAllowImplicit {
        const enabled = try arrayCallbackReturnOptionFromConfig(value, "allowImplicit", false);
        return if (enabled) .yes else .no;
    }

    fn arrayCallbackReturnCheckForEachFromConfig(value: std.json.Value) RuleConfigError!ArrayCallbackReturnCheckForEach {
        const enabled = try arrayCallbackReturnOptionFromConfig(value, "checkForEach", false);
        return if (enabled) .yes else .no;
    }

    fn arrayCallbackReturnAllowVoidFromConfig(value: std.json.Value) RuleConfigError!ArrayCallbackReturnAllowVoid {
        const enabled = try arrayCallbackReturnOptionFromConfig(value, "allowVoid", false);
        return if (enabled) .yes else .no;
    }

    fn arrayCallbackReturnOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn capitalizedCommentsModeFromConfig(value: std.json.Value) RuleConfigError!CapitalizedCommentsMode {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const mode = switch (items[1]) {
            .string => |mode| mode,
            .object => return .always,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, mode, "always")) return .always;
        if (std.mem.eql(u8, mode, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn capitalizedCommentsIgnoreInlineCommentsFromConfig(value: std.json.Value) RuleConfigError!CapitalizedCommentsIgnoreInlineComments {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config_value = switch (items[1]) {
            .object => items[1],
            .string => if (items.len >= 3) items[2] else return .no,
            else => return error.UnsupportedRuleConfigValue,
        };
        const config = switch (config_value) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const ignore = switch (config.get("ignoreInlineComments") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (ignore) .yes else .no;
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

        if (external_packages.get("@example/share-react") != null or
            external_packages.get("@example/monitor-web") != null or
            external_packages.get("moment") != null)
        {
            return .profile_a;
        }
        if (external_packages.get("@example/bridge") != null or
            external_packages.get("@example/rpc-client") != null or
            external_packages.get("statekit") != null)
        {
            return .profile_b;
        }
        return .default;
    }

    fn dotNotationAllowKeywordsFromConfig(value: std.json.Value) RuleConfigError!DotNotationAllowKeywords {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .yes,
        };
        if (items.len < 2) return .yes;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowKeywords") orelse return .yes) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
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

    fn funcNameMatchingStyleFromConfig(value: std.json.Value) RuleConfigError!FuncNameMatchingStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn funcNamesStyleFromConfig(value: std.json.Value) RuleConfigError!FuncNamesStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "as-needed")) return .as_needed;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn groupedAccessorPairsStyleFromConfig(value: std.json.Value) RuleConfigError!GroupedAccessorPairsStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .any_order,
        };
        if (items.len < 2) return .any_order;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "anyOrder")) return .any_order;
        if (std.mem.eql(u8, style, "getBeforeSet")) return .get_before_set;
        if (std.mem.eql(u8, style, "setBeforeGet")) return .set_before_get;
        return error.UnsupportedRuleConfigValue;
    }

    fn logicalAssignmentOperatorsStyleFromConfig(value: std.json.Value) RuleConfigError!LogicalAssignmentOperatorsStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            .object => return .always,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn logicalAssignmentOperatorsEnforceForIfStatementsFromConfig(value: std.json.Value) RuleConfigError!LogicalAssignmentOperatorsEnforceForIfStatements {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config_value = switch (items[1]) {
            .object => items[1],
            .string => if (items.len >= 3) items[2] else return .no,
            else => return error.UnsupportedRuleConfigValue,
        };
        const config = switch (config_value) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const enforce = switch (config.get("enforceForIfStatements") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (enforce) .yes else .no;
    }

    fn newCapBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn newCapExceptionNamesFromConfig(value: std.json.Value, key: []const u8) RuleConfigError!NewCapExceptionNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const exception_value = config.get(key) orelse return .{};
        const exception_items = switch (exception_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var exceptions = NewCapExceptionNames{};
        for (exception_items) |item| {
            const name = switch (item) {
                .string => |name| name,
                else => return error.UnsupportedRuleConfigValue,
            };
            exceptions.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return exceptions;
    }

    fn noBitwiseAllowFromConfig(value: std.json.Value, expected: []const u8) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return false;
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        for (allow_items) |item| {
            const operator = switch (item) {
                .string => |operator| operator,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (!isNoBitwiseOperatorToken(operator)) return error.UnsupportedRuleConfigValue;
            if (std.mem.eql(u8, operator, expected)) return true;
        }

        return false;
    }

    fn noBitwiseInt32HintFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("int32Hint") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noInvalidRegexpAllowConstructorFlagsFromConfig(value: std.json.Value) RuleConfigError!NoInvalidRegexpAllowConstructorFlags {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allowConstructorFlags") orelse return .{};
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var allow: NoInvalidRegexpAllowConstructorFlags = .{};
        for (allow_items) |item| {
            const flag = switch (item) {
                .string => |flag| flag,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (!allow.enable(flag)) return error.UnsupportedRuleConfigValue;
        }
        return allow;
    }

    fn isNoBitwiseOperatorToken(operator: []const u8) bool {
        inline for (.{ "&", "|", "^", "~", "<<", ">>", ">>>" }) |allowed| {
            if (std.mem.eql(u8, operator, allowed)) return true;
        }
        return false;
    }

    fn noConsoleAllowFromConfig(value: std.json.Value) RuleConfigError!NoConsoleAllow {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return .{};
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var allow: NoConsoleAllow = .{};
        for (allow_items) |item| {
            const method = switch (item) {
                .string => |method| method,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (!allow.enable(method)) return error.UnsupportedRuleConfigValue;
        }
        return allow;
    }

    fn noCondAssignStyleFromConfig(value: std.json.Value) RuleConfigError!NoCondAssignStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .except_parens,
        };
        if (items.len < 2) return .except_parens;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "except-parens")) return .except_parens;
        if (std.mem.eql(u8, style, "always")) return .always;
        return error.UnsupportedRuleConfigValue;
    }

    fn noConstantConditionCheckLoopsFromConfig(value: std.json.Value) RuleConfigError!NoConstantConditionCheckLoops {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .all_except_while_true,
        };
        if (items.len < 2) return .all_except_while_true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const check_loops = config.get("checkLoops") orelse return .all_except_while_true;
        return switch (check_loops) {
            .bool => |enabled| if (enabled) .all else .none,
            .string => |style| {
                if (std.mem.eql(u8, style, "all")) return .all;
                if (std.mem.eql(u8, style, "allExceptWhileTrue")) return .all_except_while_true;
                if (std.mem.eql(u8, style, "none")) return .none;
                return error.UnsupportedRuleConfigValue;
            },
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noConfusingArrowAllowParensFromConfig(value: std.json.Value) RuleConfigError!NoConfusingArrowAllowParens {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .yes,
        };
        if (items.len < 2) return .yes;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowParens") orelse return .yes) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noEmptyAllowEmptyCatchFromConfig(value: std.json.Value) RuleConfigError!NoEmptyAllowEmptyCatch {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowEmptyCatch") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noEmptyFunctionAllowFromConfig(value: std.json.Value) RuleConfigError!NoEmptyFunctionAllow {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return .{};
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var allow: NoEmptyFunctionAllow = .{};
        for (allow_items) |item| {
            const kind = switch (item) {
                .string => |kind| kind,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (!allow.enable(kind)) return error.UnsupportedRuleConfigValue;
        }
        return allow;
    }

    fn noElseReturnAllowElseIfFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("allowElseIf") orelse return true) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noExtraBooleanCastEnforceForInnerExpressionsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("enforceForInnerExpressions") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noFallthroughAllowEmptyCaseFromConfig(value: std.json.Value) RuleConfigError!NoFallthroughAllowEmptyCase {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowEmptyCase") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noImplicitCoercionBooleanFromConfig(value: std.json.Value) RuleConfigError!NoImplicitCoercionBoolean {
        const enabled = try noImplicitCoercionOptionFromConfig(value, "boolean");
        return if (enabled) .yes else .no;
    }

    fn noImplicitCoercionNumberFromConfig(value: std.json.Value) RuleConfigError!NoImplicitCoercionNumber {
        const enabled = try noImplicitCoercionOptionFromConfig(value, "number");
        return if (enabled) .yes else .no;
    }

    fn noImplicitCoercionStringFromConfig(value: std.json.Value) RuleConfigError!NoImplicitCoercionString {
        const enabled = try noImplicitCoercionOptionFromConfig(value, "string");
        return if (enabled) .yes else .no;
    }

    fn noImplicitCoercionOptionFromConfig(value: std.json.Value, key: []const u8) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return true) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noImplicitCoercionAllowFromConfig(value: std.json.Value, expected: []const u8) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return false;
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var found = false;
        for (allow_items) |item| {
            const allow = switch (item) {
                .string => |allow| allow,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (!isNoImplicitCoercionAllowToken(allow)) return error.UnsupportedRuleConfigValue;
            if (std.mem.eql(u8, allow, expected)) found = true;
        }
        return found;
    }

    fn isNoImplicitCoercionAllowToken(value: []const u8) bool {
        return std.mem.eql(u8, value, "!!") or
            std.mem.eql(u8, value, "~") or
            std.mem.eql(u8, value, "+") or
            std.mem.eql(u8, value, "*") or
            std.mem.eql(u8, value, "-");
    }

    fn noLabelsAllowLoopFromConfig(value: std.json.Value) RuleConfigError!NoLabelsAllowLoop {
        const enabled = try noLabelsBoolOptionFromConfig(value, "allowLoop", false);
        return if (enabled) .yes else .no;
    }

    fn noLabelsAllowSwitchFromConfig(value: std.json.Value) RuleConfigError!NoLabelsAllowSwitch {
        const enabled = try noLabelsBoolOptionFromConfig(value, "allowSwitch", false);
        return if (enabled) .yes else .no;
    }

    fn noLabelsBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noMultiSpacesIgnoreEOLCommentsFromConfig(value: std.json.Value) RuleConfigError!NoMultiSpacesIgnoreEOLComments {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const ignore = switch (config.get("ignoreEOLComments") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (ignore) .yes else .no;
    }

    fn noMultipleEmptyLinesMaxFromConfig(value: std.json.Value) RuleConfigError!usize {
        const items = switch (value) {
            .array => |array| array.items,
            else => return 2,
        };
        if (items.len < 2) return 2;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const max = switch (config.get("max") orelse return 2) {
            .integer => |max| max,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (max < 0) return error.UnsupportedRuleConfigValue;
        return @intCast(max);
    }

    fn noMultipleEmptyLinesMaxBofFromConfig(value: std.json.Value) RuleConfigError!?usize {
        const items = switch (value) {
            .array => |array| array.items,
            else => return null,
        };
        if (items.len < 2) return null;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const max = switch (config.get("maxBOF") orelse return null) {
            .integer => |max| max,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (max < 0) return error.UnsupportedRuleConfigValue;
        return @intCast(max);
    }

    fn noMultipleEmptyLinesMaxEofFromConfig(value: std.json.Value) RuleConfigError!?usize {
        const items = switch (value) {
            .array => |array| array.items,
            else => return null,
        };
        if (items.len < 2) return null;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const max = switch (config.get("maxEOF") orelse return null) {
            .integer => |max| max,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (max < 0) return error.UnsupportedRuleConfigValue;
        return @intCast(max);
    }

    fn noParamReassignPropsFromConfig(value: std.json.Value) RuleConfigError!NoParamReassignProps {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const props = switch (config.get("props") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (props) .yes else .no;
    }

    fn noParamReassignIgnoredNamesFromConfig(value: std.json.Value) RuleConfigError!NoParamReassignIgnoredNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const ignored_value = config.get("ignorePropertyModificationsFor") orelse return .{};
        const ignored_items = switch (ignored_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var ignored = NoParamReassignIgnoredNames{};
        for (ignored_items) |item| {
            const name = switch (item) {
                .string => |name| name,
                else => return error.UnsupportedRuleConfigValue,
            };
            ignored.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return ignored;
    }

    fn noShadowAllowFromConfig(value: std.json.Value) RuleConfigError!NoShadowAllowNames {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow_value = config.get("allow") orelse return .{};
        const allow_items = switch (allow_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var allow = NoShadowAllowNames{};
        for (allow_items) |item| {
            const name = switch (item) {
                .string => |name| name,
                else => return error.UnsupportedRuleConfigValue,
            };
            allow.append(name) catch return error.UnsupportedRuleConfigValue;
        }
        return allow;
    }

    fn noShadowBuiltinGlobalsFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("builtinGlobals") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noUnderscoreDangleBoolOptionFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get(key) orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noPlusplusAllowForLoopAfterthoughtsFromConfig(value: std.json.Value) RuleConfigError!NoPlusplusAllowForLoopAfterthoughts {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowForLoopAfterthoughts") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noRedeclareBuiltinGlobalsFromConfig(value: std.json.Value) RuleConfigError!NoRedeclareBuiltinGlobals {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const enabled = switch (config.get("builtinGlobals") orelse return .no) {
            .bool => |bool_value| bool_value,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (enabled) .yes else .no;
    }

    fn preferConstDestructuringFromConfig(value: std.json.Value) RuleConfigError!PreferConstDestructuring {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .any,
        };
        if (items.len < 2) return .any;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const destructuring = switch (config.get("destructuring") orelse return .any) {
            .string => |destructuring| destructuring,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, destructuring, "any")) return .any;
        if (std.mem.eql(u8, destructuring, "all")) return .all;
        return error.UnsupportedRuleConfigValue;
    }

    fn preferDestructuringOptionFromConfig(
        value: std.json.Value,
        node_key: []const u8,
        kind_key: []const u8,
        default: bool,
    ) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (config.get(node_key)) |node_config_value| {
            const node_config = switch (node_config_value) {
                .object => |object| object,
                else => return error.UnsupportedRuleConfigValue,
            };
            return switch (node_config.get(kind_key) orelse return default) {
                .bool => |enabled| enabled,
                else => error.UnsupportedRuleConfigValue,
            };
        }
        return switch (config.get(kind_key) orelse return default) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noReturnAssignStyleFromConfig(value: std.json.Value) RuleConfigError!NoReturnAssignStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .except_parens,
        };
        if (items.len < 2) return .except_parens;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "except-parens")) return .except_parens;
        if (std.mem.eql(u8, style, "always")) return .always;
        return error.UnsupportedRuleConfigValue;
    }

    fn radixStyleFromConfig(value: std.json.Value) RuleConfigError!RadixStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "as-needed")) return .as_needed;
        return error.UnsupportedRuleConfigValue;
    }

    fn noSequencesAllowInParenthesesFromConfig(value: std.json.Value) RuleConfigError!NoSequencesAllowInParentheses {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .yes,
        };
        if (items.len < 2) return .yes;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowInParentheses") orelse return .yes) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noUselessComputedKeyEnforceForClassMembersFromConfig(value: std.json.Value) RuleConfigError!NoUselessComputedKeyEnforceForClassMembers {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .yes,
        };
        if (items.len < 2) return .yes;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const enforce = switch (config.get("enforceForClassMembers") orelse return .yes) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (enforce) .yes else .no;
    }

    fn noUnusedExpressionsAllowShortCircuitFromConfig(value: std.json.Value) RuleConfigError!NoUnusedExpressionsAllowShortCircuit {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowShortCircuit") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noUnusedExpressionsAllowTernaryFromConfig(value: std.json.Value) RuleConfigError!NoUnusedExpressionsAllowTernary {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowTernary") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noUnusedExpressionsAllowTaggedTemplatesFromConfig(value: std.json.Value) RuleConfigError!NoUnusedExpressionsAllowTaggedTemplates {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowTaggedTemplates") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noUnusedVarsArgsFromConfig(value: std.json.Value, default: NoUnusedVarsArgs) RuleConfigError!NoUnusedVarsArgs {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const args = switch (config.get("args") orelse return default) {
            .string => |args| args,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, args, "none")) return .none;
        if (std.mem.eql(u8, args, "after-used")) return .after_used;
        if (std.mem.eql(u8, args, "all")) return .all;
        return error.UnsupportedRuleConfigValue;
    }

    fn noUnusedVarsCaughtErrorsFromConfig(value: std.json.Value, default: NoUnusedVarsCaughtErrors) RuleConfigError!NoUnusedVarsCaughtErrors {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const caught_errors = switch (config.get("caughtErrors") orelse return default) {
            .string => |caught_errors| caught_errors,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, caught_errors, "none")) return .none;
        if (std.mem.eql(u8, caught_errors, "all")) return .all;
        return error.UnsupportedRuleConfigValue;
    }

    fn noUnusedVarsIgnoreRestSiblingsFromConfig(value: std.json.Value, default: bool) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return default,
        };
        if (items.len < 2) return default;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("ignoreRestSiblings") orelse return default) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noUseBeforeDefineCheckFromConfig(value: std.json.Value, key: []const u8, default: bool) RuleConfigError!NoUseBeforeDefineCheck {
        const items = switch (value) {
            .array => |array| array.items,
            else => return if (default) .yes else .no,
        };
        if (items.len < 2) return if (default) .yes else .no;

        const config = switch (items[1]) {
            .string => |style| {
                if (std.mem.eql(u8, style, "nofunc")) {
                    return if (std.mem.eql(u8, key, "functions")) .no else if (default) .yes else .no;
                }
                return error.UnsupportedRuleConfigValue;
            },
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const enabled = switch (config.get(key) orelse return if (default) .yes else .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (enabled) .yes else .no;
    }

    fn objectShorthandStyleFromConfig(value: std.json.Value) RuleConfigError!ObjectShorthandStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            .object => return .always,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "methods")) return .methods;
        if (std.mem.eql(u8, style, "properties")) return .properties;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn objectShorthandAvoidQuotesFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config_value = switch (items[1]) {
            .object => items[1],
            .string => if (items.len >= 3) items[2] else return false,
            else => return error.UnsupportedRuleConfigValue,
        };
        const config = switch (config_value) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("avoidQuotes") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn operatorAssignmentStyleFromConfig(value: std.json.Value) RuleConfigError!OperatorAssignmentStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn noUndefTypeofFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("typeof") orelse return false) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
    }

    fn noUnneededTernaryDefaultAssignmentFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return true,
        };
        if (items.len < 2) return true;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("defaultAssignment") orelse return true) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn noVoidAllowAsStatementFromConfig(value: std.json.Value) RuleConfigError!NoVoidAllowAsStatement {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .no,
        };
        if (items.len < 2) return .no;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const allow = switch (config.get("allowAsStatement") orelse return .no) {
            .bool => |enabled| enabled,
            else => return error.UnsupportedRuleConfigValue,
        };
        return if (allow) .yes else .no;
    }

    fn noWarningCommentsLocationFromConfig(value: std.json.Value) RuleConfigError!NoWarningCommentsLocation {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .start,
        };
        if (items.len < 2) return .start;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const location = switch (config.get("location") orelse return .start) {
            .string => |location| location,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, location, "start")) return .start;
        if (std.mem.eql(u8, location, "anywhere")) return .anywhere;
        return error.UnsupportedRuleConfigValue;
    }

    fn noWarningCommentsDecorationFromConfig(value: std.json.Value) RuleConfigError!NoWarningCommentsDecoration {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .none,
        };
        if (items.len < 2) return .none;

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const decoration_value = config.get("decoration") orelse return .none;
        const decoration_items = switch (decoration_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var has_asterisk = false;
        var has_slash = false;
        for (decoration_items) |item| {
            const char = switch (item) {
                .string => |char| char,
                else => return error.UnsupportedRuleConfigValue,
            };
            if (std.mem.eql(u8, char, "*")) {
                has_asterisk = true;
            } else if (std.mem.eql(u8, char, "/")) {
                has_slash = true;
            } else {
                return error.UnsupportedRuleConfigValue;
            }
        }

        if (has_asterisk and has_slash) return .slash_asterisk;
        if (has_asterisk) return .asterisk;
        if (has_slash) return .slash;
        return .none;
    }

    fn noWarningCommentsTermsFromConfig(value: std.json.Value) RuleConfigError!NoWarningCommentsTerms {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .{},
        };
        if (items.len < 2) return .{};

        const config = switch (items[1]) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        const terms_value = config.get("terms") orelse return .{};
        const term_items = switch (terms_value) {
            .array => |array| array.items,
            else => return error.UnsupportedRuleConfigValue,
        };

        var terms = NoWarningCommentsTerms{};
        terms.custom = true;
        for (term_items) |item| {
            const term = switch (item) {
                .string => |term| term,
                else => return error.UnsupportedRuleConfigValue,
            };
            terms.append(term) catch return error.UnsupportedRuleConfigValue;
        }
        return terms;
    }

    fn spacedCommentStyleFromConfig(value: std.json.Value) RuleConfigError!SpacedCommentStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .always,
        };
        if (items.len < 2) return .always;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "always")) return .always;
        if (std.mem.eql(u8, style, "never")) return .never;
        return error.UnsupportedRuleConfigValue;
    }

    fn wrapIifeStyleFromConfig(value: std.json.Value) RuleConfigError!WrapIifeStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .outside,
        };
        if (items.len < 2) return .outside;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "outside")) return .outside;
        if (std.mem.eql(u8, style, "inside")) return .inside;
        if (std.mem.eql(u8, style, "any")) return .any;
        return error.UnsupportedRuleConfigValue;
    }

    fn yodaStyleFromConfig(value: std.json.Value) RuleConfigError!YodaStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .never,
        };
        if (items.len < 2) return .never;

        const style = switch (items[1]) {
            .string => |style| style,
            .object => return .never,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "never")) return .never;
        if (std.mem.eql(u8, style, "always")) return .always;
        return error.UnsupportedRuleConfigValue;
    }

    fn yodaOnlyEqualityFromConfig(value: std.json.Value) RuleConfigError!bool {
        const items = switch (value) {
            .array => |array| array.items,
            else => return false,
        };
        if (items.len < 2) return false;

        const config_value = switch (items[1]) {
            .object => items[1],
            .string => if (items.len >= 3) items[2] else return false,
            else => return error.UnsupportedRuleConfigValue,
        };
        const config = switch (config_value) {
            .object => |object| object,
            else => return error.UnsupportedRuleConfigValue,
        };
        return switch (config.get("onlyEquality") orelse return false) {
            .bool => |enabled| enabled,
            else => error.UnsupportedRuleConfigValue,
        };
    }

    fn typescriptEslintMethodSignatureStyleFromConfig(value: std.json.Value) RuleConfigError!TypescriptEslintMethodSignatureStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .property,
        };
        if (items.len < 2) return .property;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "property")) return .property;
        if (std.mem.eql(u8, style, "method")) return .method;
        return error.UnsupportedRuleConfigValue;
    }

    fn typescriptEslintClassLiteralPropertyStyleFromConfig(value: std.json.Value) RuleConfigError!TypescriptEslintClassLiteralPropertyStyle {
        const items = switch (value) {
            .array => |array| array.items,
            else => return .fields,
        };
        if (items.len < 2) return .fields;

        const style = switch (items[1]) {
            .string => |style| style,
            else => return error.UnsupportedRuleConfigValue,
        };
        if (std.mem.eql(u8, style, "fields")) return .fields;
        if (std.mem.eql(u8, style, "getters")) return .getters;
        return error.UnsupportedRuleConfigValue;
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
    profile_a,
    profile_b,
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

    var array_callback_return_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowImplicit\":false,\"checkForEach\":true,\"allowVoid\":true}]",
        .{},
    );
    defer array_callback_return_config.deinit();
    try options.setByRuleConfigValue("array-callback-return", array_callback_return_config.value);
    try std.testing.expect(options.array_callback_return);
    try std.testing.expectEqual(ArrayCallbackReturnAllowImplicit.no, options.array_callback_return_allow_implicit);
    try std.testing.expectEqual(ArrayCallbackReturnCheckForEach.yes, options.array_callback_return_check_for_each);
    try std.testing.expectEqual(ArrayCallbackReturnAllowVoid.yes, options.array_callback_return_allow_void);

    var capitalized_comments_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"ignoreInlineComments\":true}]",
        .{},
    );
    defer capitalized_comments_config.deinit();
    try options.setByRuleConfigValue("capitalized-comments", capitalized_comments_config.value);
    try std.testing.expect(options.capitalized_comments);
    try std.testing.expectEqual(CapitalizedCommentsMode.never, options.capitalized_comments_mode);
    try std.testing.expectEqual(CapitalizedCommentsIgnoreInlineComments.yes, options.capitalized_comments_ignore_inline_comments);

    var consistent_return_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"treatUndefinedAsUnspecified\":true}]",
        .{},
    );
    defer consistent_return_config.deinit();
    try options.setByRuleConfigValue("consistent-return", consistent_return_config.value);
    try std.testing.expect(options.consistent_return);
    try std.testing.expect(options.consistent_return_treat_undefined_as_unspecified);

    var dot_notation_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowKeywords\":false}]",
        .{},
    );
    defer dot_notation_config.deinit();
    try options.setByRuleConfigValue("dot-notation", dot_notation_config.value);
    try std.testing.expect(options.dot_notation);
    try std.testing.expectEqual(DotNotationAllowKeywords.no, options.dot_notation_allow_keywords);

    try options.setByRuleConfigValue("@typescript-eslint/dot-notation", .{ .string = "off" });
    try std.testing.expect(!options.typescript_eslint_dot_notation);
    try std.testing.expectEqual(DotNotationAllowKeywords.no, options.dot_notation_allow_keywords);

    var typescript_dot_notation_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowKeywords\":true}]",
        .{},
    );
    defer typescript_dot_notation_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/dot-notation", typescript_dot_notation_config.value);
    try std.testing.expect(options.typescript_eslint_dot_notation);
    try std.testing.expectEqual(DotNotationAllowKeywords.yes, options.dot_notation_allow_keywords);

    var curly_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi-line\"]",
        .{},
    );
    defer curly_config.deinit();
    try options.setByRuleConfigValue("curly", curly_config.value);
    try std.testing.expect(options.curly);
    try std.testing.expectEqual(CurlyStyle.multi_line, options.curly_style);

    var eqeqeq_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"allow-null\"]",
        .{},
    );
    defer eqeqeq_config.deinit();
    try options.setByRuleConfigValue("eqeqeq", eqeqeq_config.value);
    try std.testing.expect(options.eqeqeq);
    try std.testing.expectEqual(EqeqeqStyle.allow_null, options.eqeqeq_style);

    var accessor_pairs_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"getWithoutSet\":true,\"setWithoutGet\":false}]",
        .{},
    );
    defer accessor_pairs_config.deinit();
    try options.setByRuleConfigValue("accessor-pairs", accessor_pairs_config.value);
    try std.testing.expect(options.accessor_pairs);
    try std.testing.expectEqual(AccessorPairsGetWithoutSet.yes, options.accessor_pairs_get_without_set);
    try std.testing.expectEqual(AccessorPairsSetWithoutGet.no, options.accessor_pairs_set_without_get);

    var profile_a_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"externalPackages\":{\"moment\":\"dayjs\"}}]",
        .{},
    );
    defer profile_a_config.deinit();
    try options.setByRuleConfigValue("@alipay/ant/no-deprecated-dependence", profile_a_config.value);
    try std.testing.expectEqual(DeprecatedDependenceProfile.profile_a, options.alipay_ant_no_deprecated_dependence_profile);

    var profile_b_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"externalPackages\":{\"@example/bridge\":\"appkit\"}}]",
        .{},
    );
    defer profile_b_config.deinit();
    try options.setByRuleConfigValue("@alipay/ant/no-deprecated-dependence", profile_b_config.value);
    try std.testing.expectEqual(DeprecatedDependenceProfile.profile_b, options.alipay_ant_no_deprecated_dependence_profile);

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

    var func_name_matching_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer func_name_matching_config.deinit();
    try options.setByRuleConfigValue("func-name-matching", func_name_matching_config.value);
    try std.testing.expect(options.func_name_matching);
    try std.testing.expectEqual(FuncNameMatchingStyle.never, options.func_name_matching_style);

    var func_names_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer func_names_config.deinit();
    try options.setByRuleConfigValue("func-names", func_names_config.value);
    try std.testing.expect(options.func_names);
    try std.testing.expectEqual(FuncNamesStyle.never, options.func_names_style);

    var grouped_accessor_pairs_get_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"getBeforeSet\"]",
        .{},
    );
    defer grouped_accessor_pairs_get_config.deinit();
    try options.setByRuleConfigValue("grouped-accessor-pairs", grouped_accessor_pairs_get_config.value);
    try std.testing.expect(options.grouped_accessor_pairs);
    try std.testing.expectEqual(GroupedAccessorPairsStyle.get_before_set, options.grouped_accessor_pairs_style);

    var grouped_accessor_pairs_set_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"setBeforeGet\"]",
        .{},
    );
    defer grouped_accessor_pairs_set_config.deinit();
    try options.setByRuleConfigValue("grouped-accessor-pairs", grouped_accessor_pairs_set_config.value);
    try std.testing.expect(options.grouped_accessor_pairs);
    try std.testing.expectEqual(GroupedAccessorPairsStyle.set_before_get, options.grouped_accessor_pairs_style);

    var logical_assignment_operators_never_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer logical_assignment_operators_never_config.deinit();
    try options.setByRuleConfigValue("logical-assignment-operators", logical_assignment_operators_never_config.value);
    try std.testing.expect(options.logical_assignment_operators);
    try std.testing.expectEqual(LogicalAssignmentOperatorsStyle.never, options.logical_assignment_operators_style);

    var logical_assignment_operators_if_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"enforceForIfStatements\":true}]",
        .{},
    );
    defer logical_assignment_operators_if_config.deinit();
    try options.setByRuleConfigValue("logical-assignment-operators", logical_assignment_operators_if_config.value);
    try std.testing.expect(options.logical_assignment_operators);
    try std.testing.expectEqual(LogicalAssignmentOperatorsStyle.always, options.logical_assignment_operators_style);
    try std.testing.expectEqual(
        LogicalAssignmentOperatorsEnforceForIfStatements.yes,
        options.logical_assignment_operators_enforce_for_if_statements,
    );

    var no_bitwise_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"|\",\"~\",\">>\"],\"int32Hint\":true}]",
        .{},
    );
    defer no_bitwise_config.deinit();
    try options.setByRuleConfigValue("no-bitwise", no_bitwise_config.value);
    try std.testing.expect(options.no_bitwise);
    try std.testing.expect(!options.no_bitwise_allow_bitwise_and);
    try std.testing.expect(options.no_bitwise_allow_bitwise_or);
    try std.testing.expect(!options.no_bitwise_allow_bitwise_xor);
    try std.testing.expect(options.no_bitwise_allow_bitwise_not);
    try std.testing.expect(!options.no_bitwise_allow_left_shift);
    try std.testing.expect(options.no_bitwise_allow_right_shift);
    try std.testing.expect(!options.no_bitwise_allow_unsigned_right_shift);
    try std.testing.expect(options.no_bitwise_int32_hint);

    var no_console_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"warn\",\"error\"]}]",
        .{},
    );
    defer no_console_config.deinit();
    try options.setByRuleConfigValue("no-console", no_console_config.value);
    try std.testing.expect(options.no_console);
    try std.testing.expect(options.no_console_allow.contains("warn"));
    try std.testing.expect(options.no_console_allow.contains("error"));
    try std.testing.expect(!options.no_console_allow.contains("log"));

    var no_cond_assign_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\"]",
        .{},
    );
    defer no_cond_assign_config.deinit();
    try options.setByRuleConfigValue("no-cond-assign", no_cond_assign_config.value);
    try std.testing.expect(options.no_cond_assign);
    try std.testing.expectEqual(NoCondAssignStyle.always, options.no_cond_assign_style);

    var no_constant_condition_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"checkLoops\":\"none\"}]",
        .{},
    );
    defer no_constant_condition_config.deinit();
    try options.setByRuleConfigValue("no-constant-condition", no_constant_condition_config.value);
    try std.testing.expect(options.no_constant_condition);
    try std.testing.expectEqual(NoConstantConditionCheckLoops.none, options.no_constant_condition_check_loops);

    var no_constant_condition_false_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"checkLoops\":false}]",
        .{},
    );
    defer no_constant_condition_false_config.deinit();
    try options.setByRuleConfigValue("no-constant-condition", no_constant_condition_false_config.value);
    try std.testing.expectEqual(NoConstantConditionCheckLoops.none, options.no_constant_condition_check_loops);

    var no_confusing_arrow_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowParens\":false}]",
        .{},
    );
    defer no_confusing_arrow_config.deinit();
    try options.setByRuleConfigValue("no-confusing-arrow", no_confusing_arrow_config.value);
    try std.testing.expect(options.no_confusing_arrow);
    try std.testing.expectEqual(NoConfusingArrowAllowParens.no, options.no_confusing_arrow_allow_parens);

    var no_empty_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowEmptyCatch\":true}]",
        .{},
    );
    defer no_empty_config.deinit();
    try options.setByRuleConfigValue("no-empty", no_empty_config.value);
    try std.testing.expect(options.no_empty);
    try std.testing.expectEqual(NoEmptyAllowEmptyCatch.yes, options.no_empty_allow_empty_catch);

    var no_empty_function_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"functions\",\"constructors\"]}]",
        .{},
    );
    defer no_empty_function_config.deinit();
    try options.setByRuleConfigValue("no-empty-function", no_empty_function_config.value);
    try std.testing.expect(options.no_empty_function);
    try std.testing.expect(options.no_empty_function_allow.functions);
    try std.testing.expect(options.no_empty_function_allow.constructors);
    try std.testing.expect(!options.no_empty_function_allow.arrowFunctions);

    var no_empty_function_extended_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"asyncFunctions\",\"generatorFunctions\",\"asyncMethods\",\"generatorMethods\",\"getters\",\"setters\"]}]",
        .{},
    );
    defer no_empty_function_extended_config.deinit();
    try options.setByRuleConfigValue("no-empty-function", no_empty_function_extended_config.value);
    try std.testing.expect(options.no_empty_function_allow.asyncFunctions);
    try std.testing.expect(options.no_empty_function_allow.generatorFunctions);
    try std.testing.expect(options.no_empty_function_allow.asyncMethods);
    try std.testing.expect(options.no_empty_function_allow.generatorMethods);
    try std.testing.expect(options.no_empty_function_allow.getters);
    try std.testing.expect(options.no_empty_function_allow.setters);

    var typescript_no_empty_function_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"arrowFunctions\",\"methods\"]}]",
        .{},
    );
    defer typescript_no_empty_function_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-empty-function", typescript_no_empty_function_config.value);
    try std.testing.expect(options.typescript_eslint_no_empty_function);
    try std.testing.expect(options.typescript_eslint_no_empty_function_allow.arrowFunctions);
    try std.testing.expect(options.typescript_eslint_no_empty_function_allow.methods);
    try std.testing.expect(!options.typescript_eslint_no_empty_function_allow.functions);

    var no_else_return_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowElseIf\":false}]",
        .{},
    );
    defer no_else_return_config.deinit();
    try options.setByRuleConfigValue("no-else-return", no_else_return_config.value);
    try std.testing.expect(options.no_else_return);
    try std.testing.expect(!options.no_else_return_allow_else_if);

    var no_extra_boolean_cast_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForInnerExpressions\":true}]",
        .{},
    );
    defer no_extra_boolean_cast_config.deinit();
    try options.setByRuleConfigValue("no-extra-boolean-cast", no_extra_boolean_cast_config.value);
    try std.testing.expect(options.no_extra_boolean_cast);
    try std.testing.expect(options.no_extra_boolean_cast_enforce_for_inner_expressions);

    var no_fallthrough_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowEmptyCase\":true}]",
        .{},
    );
    defer no_fallthrough_config.deinit();
    try options.setByRuleConfigValue("no-fallthrough", no_fallthrough_config.value);
    try std.testing.expect(options.no_fallthrough);
    try std.testing.expectEqual(NoFallthroughAllowEmptyCase.yes, options.no_fallthrough_allow_empty_case);

    var no_implicit_coercion_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"boolean\":false,\"number\":false,\"string\":true}]",
        .{},
    );
    defer no_implicit_coercion_config.deinit();
    try options.setByRuleConfigValue("no-implicit-coercion", no_implicit_coercion_config.value);
    try std.testing.expect(options.no_implicit_coercion);
    try std.testing.expectEqual(NoImplicitCoercionBoolean.no, options.no_implicit_coercion_boolean);
    try std.testing.expectEqual(NoImplicitCoercionNumber.no, options.no_implicit_coercion_number);
    try std.testing.expectEqual(NoImplicitCoercionString.yes, options.no_implicit_coercion_string);

    var no_implicit_coercion_allow_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"!!\",\"~\",\"+\",\"*\",\"-\"]}]",
        .{},
    );
    defer no_implicit_coercion_allow_config.deinit();
    try options.setByRuleConfigValue("no-implicit-coercion", no_implicit_coercion_allow_config.value);
    try std.testing.expect(options.no_implicit_coercion_allow_double_negation);
    try std.testing.expect(options.no_implicit_coercion_allow_bitwise_not);
    try std.testing.expect(options.no_implicit_coercion_allow_unary_plus);
    try std.testing.expect(options.no_implicit_coercion_allow_multiply);
    try std.testing.expect(options.no_implicit_coercion_allow_subtract);

    var no_labels_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowLoop\":true,\"allowSwitch\":true}]",
        .{},
    );
    defer no_labels_config.deinit();
    try options.setByRuleConfigValue("no-labels", no_labels_config.value);
    try std.testing.expect(options.no_labels);
    try std.testing.expectEqual(NoLabelsAllowLoop.yes, options.no_labels_allow_loop);
    try std.testing.expectEqual(NoLabelsAllowSwitch.yes, options.no_labels_allow_switch);

    var new_cap_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"newIsCap\":false,\"capIsNew\":false,\"properties\":false,\"newIsCapExceptions\":[\"lowerFactory\"],\"capIsNewExceptions\":[\"UpperFactory\"]}]",
        .{},
    );
    defer new_cap_config.deinit();
    try options.setByRuleConfigValue("new-cap", new_cap_config.value);
    try std.testing.expect(options.new_cap);
    try std.testing.expect(!options.new_cap_new_is_cap);
    try std.testing.expect(!options.new_cap_cap_is_new);
    try std.testing.expect(!options.new_cap_properties);
    try std.testing.expect(options.new_cap_new_is_cap_exceptions.contains("lowerFactory"));
    try std.testing.expect(!options.new_cap_new_is_cap_exceptions.contains("otherFactory"));
    try std.testing.expect(options.new_cap_cap_is_new_exceptions.contains("UpperFactory"));
    try std.testing.expect(!options.new_cap_cap_is_new_exceptions.contains("OtherFactory"));

    var no_multi_spaces_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreEOLComments\":true}]",
        .{},
    );
    defer no_multi_spaces_config.deinit();
    try options.setByRuleConfigValue("no-multi-spaces", no_multi_spaces_config.value);
    try std.testing.expect(options.no_multi_spaces);
    try std.testing.expectEqual(NoMultiSpacesIgnoreEOLComments.yes, options.no_multi_spaces_ignore_eol_comments);

    var no_multiple_empty_lines_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"max\":1}]",
        .{},
    );
    defer no_multiple_empty_lines_config.deinit();
    try options.setByRuleConfigValue("no-multiple-empty-lines", no_multiple_empty_lines_config.value);
    try std.testing.expect(options.no_multiple_empty_lines);
    try std.testing.expectEqual(@as(usize, 1), options.no_multiple_empty_lines_max);
    try std.testing.expectEqual(@as(?usize, null), options.no_multiple_empty_lines_max_bof);
    try std.testing.expectEqual(@as(?usize, null), options.no_multiple_empty_lines_max_eof);

    var no_multiple_empty_lines_bof_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"maxBOF\":0}]",
        .{},
    );
    defer no_multiple_empty_lines_bof_config.deinit();
    try options.setByRuleConfigValue("no-multiple-empty-lines", no_multiple_empty_lines_bof_config.value);
    try std.testing.expect(options.no_multiple_empty_lines);
    try std.testing.expectEqual(@as(usize, 2), options.no_multiple_empty_lines_max);
    try std.testing.expectEqual(@as(?usize, 0), options.no_multiple_empty_lines_max_bof);
    try std.testing.expectEqual(@as(?usize, null), options.no_multiple_empty_lines_max_eof);

    var no_multiple_empty_lines_eof_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"maxEOF\":0}]",
        .{},
    );
    defer no_multiple_empty_lines_eof_config.deinit();
    try options.setByRuleConfigValue("no-multiple-empty-lines", no_multiple_empty_lines_eof_config.value);
    try std.testing.expect(options.no_multiple_empty_lines);
    try std.testing.expectEqual(@as(usize, 2), options.no_multiple_empty_lines_max);
    try std.testing.expectEqual(@as(?usize, null), options.no_multiple_empty_lines_max_bof);
    try std.testing.expectEqual(@as(?usize, 0), options.no_multiple_empty_lines_max_eof);

    var no_param_reassign_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"props\":true,\"ignorePropertyModificationsFor\":[\"req\",\"res\"]}]",
        .{},
    );
    defer no_param_reassign_config.deinit();
    try options.setByRuleConfigValue("no-param-reassign", no_param_reassign_config.value);
    try std.testing.expect(options.no_param_reassign);
    try std.testing.expectEqual(NoParamReassignProps.yes, options.no_param_reassign_props);
    try std.testing.expect(options.no_param_reassign_ignore_property_modifications_for.contains("req"));
    try std.testing.expect(options.no_param_reassign_ignore_property_modifications_for.contains("res"));
    try std.testing.expect(!options.no_param_reassign_ignore_property_modifications_for.contains("ctx"));

    var no_redeclare_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"builtinGlobals\":true}]",
        .{},
    );
    defer no_redeclare_config.deinit();
    try options.setByRuleConfigValue("no-redeclare", no_redeclare_config.value);
    try std.testing.expect(options.no_redeclare);
    try std.testing.expectEqual(NoRedeclareBuiltinGlobals.yes, options.no_redeclare_builtin_globals);

    var no_shadow_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"done\"],\"builtinGlobals\":true}]",
        .{},
    );
    defer no_shadow_config.deinit();
    try options.setByRuleConfigValue("no-shadow", no_shadow_config.value);
    try std.testing.expect(options.no_shadow);
    try std.testing.expect(options.no_shadow_allow.contains("done"));
    try std.testing.expect(!options.no_shadow_allow.contains("other"));
    try std.testing.expect(options.no_shadow_builtin_globals);

    var no_underscore_dangle_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowAfterThis\":true,\"allowAfterSuper\":true,\"allowAfterThisConstructor\":true,\"allowFunctionParams\":false,\"allowInArrayDestructuring\":false,\"allowInObjectDestructuring\":false,\"enforceInMethodNames\":true,\"enforceInClassFields\":true}]",
        .{},
    );
    defer no_underscore_dangle_config.deinit();
    try options.setByRuleConfigValue("no-underscore-dangle", no_underscore_dangle_config.value);
    try std.testing.expect(options.no_underscore_dangle);
    try std.testing.expect(options.no_underscore_dangle_allow_after_this);
    try std.testing.expect(options.no_underscore_dangle_allow_after_super);
    try std.testing.expect(options.no_underscore_dangle_allow_after_this_constructor);
    try std.testing.expectEqual(NoUnderscoreDangleAllowFunctionParams.no, options.no_underscore_dangle_allow_function_params);
    try std.testing.expectEqual(NoUnderscoreDangleAllowDestructuring.no, options.no_underscore_dangle_allow_in_array_destructuring);
    try std.testing.expectEqual(NoUnderscoreDangleAllowDestructuring.no, options.no_underscore_dangle_allow_in_object_destructuring);
    try std.testing.expect(options.no_underscore_dangle_enforce_in_method_names);
    try std.testing.expect(options.no_underscore_dangle_enforce_in_class_fields);

    var typescript_no_shadow_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"value\"],\"builtinGlobals\":true}]",
        .{},
    );
    defer typescript_no_shadow_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-shadow", typescript_no_shadow_config.value);
    try std.testing.expect(options.typescript_eslint_no_shadow);
    try std.testing.expect(options.typescript_eslint_no_shadow_allow.contains("value"));
    try std.testing.expect(!options.typescript_eslint_no_shadow_allow.contains("other"));
    try std.testing.expect(options.typescript_eslint_no_shadow_builtin_globals);

    var no_plusplus_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowForLoopAfterthoughts\":true}]",
        .{},
    );
    defer no_plusplus_config.deinit();
    try options.setByRuleConfigValue("no-plusplus", no_plusplus_config.value);
    try std.testing.expect(options.no_plusplus);
    try std.testing.expectEqual(NoPlusplusAllowForLoopAfterthoughts.yes, options.no_plusplus_allow_for_loop_afterthoughts);

    var object_shorthand_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"methods\",{\"avoidQuotes\":true}]",
        .{},
    );
    defer object_shorthand_config.deinit();
    try options.setByRuleConfigValue("object-shorthand", object_shorthand_config.value);
    try std.testing.expect(options.object_shorthand);
    try std.testing.expectEqual(ObjectShorthandStyle.methods, options.object_shorthand_style);
    try std.testing.expect(options.object_shorthand_avoid_quotes);

    var operator_assignment_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer operator_assignment_config.deinit();
    try options.setByRuleConfigValue("operator-assignment", operator_assignment_config.value);
    try std.testing.expect(options.operator_assignment);
    try std.testing.expectEqual(OperatorAssignmentStyle.never, options.operator_assignment_style);

    var prefer_const_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"destructuring\":\"all\"}]",
        .{},
    );
    defer prefer_const_config.deinit();
    try options.setByRuleConfigValue("prefer-const", prefer_const_config.value);
    try std.testing.expect(options.prefer_const);
    try std.testing.expectEqual(PreferConstDestructuring.all, options.prefer_const_destructuring);

    var prefer_destructuring_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"VariableDeclarator\":{\"array\":false,\"object\":true},\"AssignmentExpression\":{\"array\":true,\"object\":false}}]",
        .{},
    );
    defer prefer_destructuring_config.deinit();
    try options.setByRuleConfigValue("prefer-destructuring", prefer_destructuring_config.value);
    try std.testing.expect(options.prefer_destructuring);
    try std.testing.expect(!options.prefer_destructuring_variable_declarator_array);
    try std.testing.expect(options.prefer_destructuring_variable_declarator_object);
    try std.testing.expect(options.prefer_destructuring_assignment_expression_array);
    try std.testing.expect(!options.prefer_destructuring_assignment_expression_object);

    var prefer_destructuring_top_level_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"array\":false,\"object\":true}]",
        .{},
    );
    defer prefer_destructuring_top_level_config.deinit();
    try options.setByRuleConfigValue("prefer-destructuring", prefer_destructuring_top_level_config.value);
    try std.testing.expect(!options.prefer_destructuring_variable_declarator_array);
    try std.testing.expect(options.prefer_destructuring_variable_declarator_object);
    try std.testing.expect(!options.prefer_destructuring_assignment_expression_array);
    try std.testing.expect(options.prefer_destructuring_assignment_expression_object);

    var radix_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"as-needed\"]",
        .{},
    );
    defer radix_config.deinit();
    try options.setByRuleConfigValue("radix", radix_config.value);
    try std.testing.expect(options.radix);
    try std.testing.expectEqual(RadixStyle.as_needed, options.radix_style);

    var no_return_assign_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\"]",
        .{},
    );
    defer no_return_assign_config.deinit();
    try options.setByRuleConfigValue("no-return-assign", no_return_assign_config.value);
    try std.testing.expect(options.no_return_assign);
    try std.testing.expectEqual(NoReturnAssignStyle.always, options.no_return_assign_style);

    var no_sequences_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowInParentheses\":false}]",
        .{},
    );
    defer no_sequences_config.deinit();
    try options.setByRuleConfigValue("no-sequences", no_sequences_config.value);
    try std.testing.expect(options.no_sequences);
    try std.testing.expectEqual(NoSequencesAllowInParentheses.no, options.no_sequences_allow_in_parentheses);

    var no_useless_computed_key_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForClassMembers\":false}]",
        .{},
    );
    defer no_useless_computed_key_config.deinit();
    try options.setByRuleConfigValue("no-useless-computed-key", no_useless_computed_key_config.value);
    try std.testing.expect(options.no_useless_computed_key);
    try std.testing.expectEqual(
        NoUselessComputedKeyEnforceForClassMembers.no,
        options.no_useless_computed_key_enforce_for_class_members,
    );

    var no_unused_expressions_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowShortCircuit\":true,\"allowTernary\":true,\"allowTaggedTemplates\":false}]",
        .{},
    );
    defer no_unused_expressions_config.deinit();
    try options.setByRuleConfigValue("no-unused-expressions", no_unused_expressions_config.value);
    try std.testing.expect(options.no_unused_expressions);
    try std.testing.expectEqual(NoUnusedExpressionsAllowShortCircuit.yes, options.no_unused_expressions_allow_short_circuit);
    try std.testing.expectEqual(NoUnusedExpressionsAllowTernary.yes, options.no_unused_expressions_allow_ternary);
    try std.testing.expectEqual(NoUnusedExpressionsAllowTaggedTemplates.no, options.no_unused_expressions_allow_tagged_templates);

    var no_unused_expressions_default_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\"]",
        .{},
    );
    defer no_unused_expressions_default_config.deinit();
    try options.setByRuleConfigValue("no-unused-expressions", no_unused_expressions_default_config.value);
    try std.testing.expectEqual(NoUnusedExpressionsAllowTaggedTemplates.no, options.no_unused_expressions_allow_tagged_templates);

    var no_unused_vars_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"args\":\"all\",\"caughtErrors\":\"none\",\"ignoreRestSiblings\":true}]",
        .{},
    );
    defer no_unused_vars_config.deinit();
    try options.setByRuleConfigValue("no-unused-vars", no_unused_vars_config.value);
    try std.testing.expect(options.no_unused_vars);
    try std.testing.expectEqual(NoUnusedVarsArgs.all, options.no_unused_vars_args);
    try std.testing.expectEqual(NoUnusedVarsCaughtErrors.none, options.no_unused_vars_caught_errors);
    try std.testing.expect(options.no_unused_vars_ignore_rest_siblings);

    var typescript_no_unused_vars_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"args\":\"none\",\"caughtErrors\":\"none\",\"ignoreRestSiblings\":false}]",
        .{},
    );
    defer typescript_no_unused_vars_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-unused-vars", typescript_no_unused_vars_config.value);
    try std.testing.expect(options.typescript_eslint_no_unused_vars);
    try std.testing.expectEqual(NoUnusedVarsArgs.none, options.typescript_eslint_no_unused_vars_args);
    try std.testing.expectEqual(NoUnusedVarsCaughtErrors.none, options.typescript_eslint_no_unused_vars_caught_errors);
    try std.testing.expect(!options.typescript_eslint_no_unused_vars_ignore_rest_siblings);

    var no_use_before_define_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"functions\":false,\"classes\":false}]",
        .{},
    );
    defer no_use_before_define_config.deinit();
    try options.setByRuleConfigValue("no-use-before-define", no_use_before_define_config.value);
    try std.testing.expect(options.no_use_before_define);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.no_use_before_define_check_functions);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.no_use_before_define_check_classes);

    var no_use_before_define_nofunc_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"nofunc\"]",
        .{},
    );
    defer no_use_before_define_nofunc_config.deinit();
    try options.setByRuleConfigValue("no-use-before-define", no_use_before_define_nofunc_config.value);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.no_use_before_define_check_functions);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.yes, options.no_use_before_define_check_classes);

    var no_undef_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"typeof\":true}]",
        .{},
    );
    defer no_undef_config.deinit();
    try options.setByRuleConfigValue("no-undef", no_undef_config.value);
    try std.testing.expect(options.no_undef);
    try std.testing.expect(options.no_undef_typeof);

    var no_unneeded_ternary_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"defaultAssignment\":false}]",
        .{},
    );
    defer no_unneeded_ternary_config.deinit();
    try options.setByRuleConfigValue("no-unneeded-ternary", no_unneeded_ternary_config.value);
    try std.testing.expect(options.no_unneeded_ternary);
    try std.testing.expect(!options.no_unneeded_ternary_default_assignment);

    var typescript_no_use_before_define_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"functions\":true,\"classes\":false}]",
        .{},
    );
    defer typescript_no_use_before_define_config.deinit();
    try options.setByRuleConfigValue("@typescript-eslint/no-use-before-define", typescript_no_use_before_define_config.value);
    try std.testing.expect(options.typescript_eslint_no_use_before_define);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.yes, options.typescript_eslint_no_use_before_define_check_functions);
    try std.testing.expectEqual(NoUseBeforeDefineCheck.no, options.typescript_eslint_no_use_before_define_check_classes);

    var no_void_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowAsStatement\":true}]",
        .{},
    );
    defer no_void_config.deinit();
    try options.setByRuleConfigValue("no-void", no_void_config.value);
    try std.testing.expect(options.no_void);
    try std.testing.expectEqual(NoVoidAllowAsStatement.yes, options.no_void_allow_as_statement);

    var no_warning_comments_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"terms\":[\"review\",\"blocked by upstream\"],\"location\":\"anywhere\",\"decoration\":[\"/\",\"*\"]}]",
        .{},
    );
    defer no_warning_comments_config.deinit();
    try options.setByRuleConfigValue("no-warning-comments", no_warning_comments_config.value);
    try std.testing.expect(options.no_warning_comments);
    try std.testing.expectEqual(NoWarningCommentsLocation.anywhere, options.no_warning_comments_location);
    try std.testing.expectEqual(NoWarningCommentsDecoration.slash_asterisk, options.no_warning_comments_decoration);
    try std.testing.expectEqual(@as(usize, 2), options.no_warning_comments_terms.len());
    try std.testing.expectEqualStrings("review", options.no_warning_comments_terms.at(0));
    try std.testing.expectEqualStrings("blocked by upstream", options.no_warning_comments_terms.at(1));

    var spaced_comment_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer spaced_comment_config.deinit();
    try options.setByRuleConfigValue("spaced-comment", spaced_comment_config.value);
    try std.testing.expect(options.spaced_comment);
    try std.testing.expectEqual(SpacedCommentStyle.never, options.spaced_comment_style);

    var wrap_iife_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"inside\"]",
        .{},
    );
    defer wrap_iife_config.deinit();
    try options.setByRuleConfigValue("wrap-iife", wrap_iife_config.value);
    try std.testing.expect(options.wrap_iife);
    try std.testing.expectEqual(WrapIifeStyle.inside, options.wrap_iife_style);

    var yoda_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\"]",
        .{},
    );
    defer yoda_config.deinit();
    try options.setByRuleConfigValue("yoda", yoda_config.value);
    try std.testing.expect(options.yoda);
    try std.testing.expectEqual(YodaStyle.always, options.yoda_style);

    var yoda_only_equality_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"onlyEquality\":true}]",
        .{},
    );
    defer yoda_only_equality_config.deinit();
    try options.setByRuleConfigValue("yoda", yoda_only_equality_config.value);
    try std.testing.expectEqual(YodaStyle.never, options.yoda_style);
    try std.testing.expect(options.yoda_only_equality);

    try std.testing.expectError(
        Options.RuleConfigError.UnsupportedRuleConfigValue,
        options.setByRuleConfigValue("no-debugger", .{ .string = "sometimes" }),
    );
    try std.testing.expectError(
        Options.RuleConfigError.UnknownRule,
        options.setByRuleConfigValue("unknown-rule", .{ .string = "off" }),
    );
}
