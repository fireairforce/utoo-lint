const std = @import("std");
const lint = @import("utoo_lint");

const max_file_size = 64 * 1024 * 1024;
const max_config_file_size = 1024 * 1024;

const Stats = struct {
    files: usize = 0,
    diagnostics: usize = 0,
    errors: usize = 0,

    fn add(self: *Stats, other: Stats) void {
        self.files += other.files;
        self.diagnostics += other.diagnostics;
        self.errors += other.errors;
    }
};

const OutputFormat = enum {
    text,
    json,
};

const JsonDiagnostic = struct {
    @"filePath": []const u8,
    line: usize,
    column: usize,
    severity: []const u8,
    message: []const u8,
    @"ruleId": []const u8,
};

const JsonDiagnosticList = std.ArrayList(JsonDiagnostic);

const JsonReport = struct {
    files: usize,
    diagnostics: []const JsonDiagnostic,
};

const WorkQueue = struct {
    io: std.Io,
    files: []const []const u8,
    options: lint.Options,
    next_index: std.atomic.Value(usize) = .init(0),
    print_mutex: std.Io.Mutex = .init,
};

const WorkerResult = struct {
    stats: Stats = .{},
    err: ?anyerror = null,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (hasHelpArg(args[1..])) {
        printHelp();
        return;
    }

    var options = lint.Options{};
    const config = parseConfigArgs(args[1..]);
    if (config.enabled) {
        if (config.path) |path| {
            try loadConfigFile(allocator, io, path, true, &options);
        } else if (findDefaultConfig(io)) |path| {
            try loadConfigFile(allocator, io, path, false, &options);
        }
    }

    var thread_count_override: ?usize = null;
    var output_format: OutputFormat = .text;
    var targets: std.ArrayList([]const u8) = .empty;
    defer targets.deinit(allocator);

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            return;
        } else if (std.mem.eql(u8, arg, "--no-config")) {
            continue;
        } else if (std.mem.startsWith(u8, arg, "--config=")) {
            continue;
        } else if (std.mem.startsWith(u8, arg, "--threads=")) {
            const value = arg["--threads=".len..];
            const parsed = std.fmt.parseInt(usize, value, 10) catch {
                std.debug.print("utoo-lint: invalid --threads value: {s}\n", .{value});
                std.process.exit(2);
            };
            if (parsed == 0) {
                std.debug.print("utoo-lint: --threads must be greater than 0\n", .{});
                std.process.exit(2);
            }
            thread_count_override = parsed;
        } else if (std.mem.eql(u8, arg, "--json")) {
            output_format = .json;
        } else if (std.mem.startsWith(u8, arg, "--format=")) {
            const value = arg["--format=".len..];
            output_format = parseOutputFormat(value) orelse {
                std.debug.print("utoo-lint: invalid --format value: {s}\n", .{value});
                std.process.exit(2);
            };
        } else if (std.mem.startsWith(u8, arg, "--rules=")) {
            options = lint.Options.allDisabled();
            parseEnabledRules(arg["--rules=".len..], &options);
        } else if (std.mem.eql(u8, arg, "--constructor-super=off")) {
            options.constructor_super = false;
        } else if (std.mem.eql(u8, arg, "--array-callback-return=off")) {
            options.array_callback_return = false;
        } else if (std.mem.eql(u8, arg, "--block-scoped-var=off")) {
            options.block_scoped_var = false;
        } else if (std.mem.eql(u8, arg, "--curly=off")) {
            options.curly = false;
        } else if (std.mem.eql(u8, arg, "--dot-notation=off")) {
            options.dot_notation = false;
        } else if (std.mem.eql(u8, arg, "--default-case=off")) {
            options.default_case = false;
        } else if (std.mem.eql(u8, arg, "--default-case-last=off")) {
            options.default_case_last = false;
        } else if (std.mem.eql(u8, arg, "--eol-last=off")) {
            options.eol_last = false;
        } else if (std.mem.eql(u8, arg, "--for-direction=off")) {
            options.for_direction = false;
        } else if (std.mem.eql(u8, arg, "--getter-return=off")) {
            options.getter_return = false;
        } else if (std.mem.eql(u8, arg, "--guard-for-in=off")) {
            options.guard_for_in = false;
        } else if (std.mem.eql(u8, arg, "--linebreak-style=off")) {
            options.linebreak_style = false;
        } else if (std.mem.eql(u8, arg, "--new-cap=off")) {
            options.new_cap = false;
        } else if (std.mem.eql(u8, arg, "--new-parens=off")) {
            options.new_parens = false;
        } else if (std.mem.eql(u8, arg, "--no-async-promise-executor=off")) {
            options.no_async_promise_executor = false;
        } else if (std.mem.eql(u8, arg, "--no-array-constructor=off")) {
            options.no_array_constructor = false;
        } else if (std.mem.eql(u8, arg, "--no-await-in-loop=off")) {
            options.no_await_in_loop = false;
        } else if (std.mem.eql(u8, arg, "--no-alert=off")) {
            options.no_alert = false;
        } else if (std.mem.eql(u8, arg, "--no-bitwise=off")) {
            options.no_bitwise = false;
        } else if (std.mem.eql(u8, arg, "--no-buffer-constructor=off")) {
            options.no_buffer_constructor = false;
        } else if (std.mem.eql(u8, arg, "--no-caller=off")) {
            options.no_caller = false;
        } else if (std.mem.eql(u8, arg, "--no-case-declarations=off")) {
            options.no_case_declarations = false;
        } else if (std.mem.eql(u8, arg, "--no-class-assign=off")) {
            options.no_class_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-cond-assign=off")) {
            options.no_cond_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-compare-neg-zero=off")) {
            options.no_compare_neg_zero = false;
        } else if (std.mem.eql(u8, arg, "--no-constant-condition=off")) {
            options.no_constant_condition = false;
        } else if (std.mem.eql(u8, arg, "--no-const-assign=off")) {
            options.no_const_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-control-regex=off")) {
            options.no_control_regex = false;
        } else if (std.mem.eql(u8, arg, "--no-console=off")) {
            options.no_console = false;
        } else if (std.mem.eql(u8, arg, "--no-comma-operator=off")) {
            options.no_comma_operator = false;
        } else if (std.mem.eql(u8, arg, "--no-continue=off")) {
            options.no_continue = false;
        } else if (std.mem.eql(u8, arg, "--no-constructor-return=off")) {
            options.no_constructor_return = false;
        } else if (std.mem.eql(u8, arg, "--no-debugger=off")) {
            options.no_debugger = false;
        } else if (std.mem.eql(u8, arg, "--no-dupe-else-if=off")) {
            options.no_dupe_else_if = false;
        } else if (std.mem.eql(u8, arg, "--no-duplicate-case=off")) {
            options.no_duplicate_case = false;
        } else if (std.mem.eql(u8, arg, "--no-duplicate-imports=off")) {
            options.no_duplicate_imports = false;
        } else if (std.mem.eql(u8, arg, "--no-dupe-args=off")) {
            options.no_dupe_args = false;
        } else if (std.mem.eql(u8, arg, "--no-dupe-class-members=off")) {
            options.no_dupe_class_members = false;
        } else if (std.mem.eql(u8, arg, "--no-dupe-keys=off")) {
            options.no_dupe_keys = false;
        } else if (std.mem.eql(u8, arg, "--no-delete-var=off")) {
            options.no_delete_var = false;
        } else if (std.mem.eql(u8, arg, "--no-div-regex=off")) {
            options.no_div_regex = false;
        } else if (std.mem.eql(u8, arg, "--no-empty=off")) {
            options.no_empty = false;
        } else if (std.mem.eql(u8, arg, "--no-empty-block-statements=off")) {
            options.no_empty_block_statements = false;
        } else if (std.mem.eql(u8, arg, "--no-empty-character-class=off")) {
            options.no_empty_character_class = false;
        } else if (std.mem.eql(u8, arg, "--no-empty-function=off")) {
            options.no_empty_function = false;
        } else if (std.mem.eql(u8, arg, "--no-empty-pattern=off")) {
            options.no_empty_pattern = false;
        } else if (std.mem.eql(u8, arg, "--no-empty-static-block=off")) {
            options.no_empty_static_block = false;
        } else if (std.mem.eql(u8, arg, "--no-else-return=off")) {
            options.no_else_return = false;
        } else if (std.mem.eql(u8, arg, "--no-eq-null=off")) {
            options.no_eq_null = false;
        } else if (std.mem.eql(u8, arg, "--no-eval=off")) {
            options.no_eval = false;
        } else if (std.mem.eql(u8, arg, "--no-ex-assign=off")) {
            options.no_ex_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-extend-native=off")) {
            options.no_extend_native = false;
        } else if (std.mem.eql(u8, arg, "--no-extra-bind=off")) {
            options.no_extra_bind = false;
        } else if (std.mem.eql(u8, arg, "--no-extra-label=off")) {
            options.no_extra_label = false;
        } else if (std.mem.eql(u8, arg, "--no-extra-semi=off")) {
            options.no_extra_semi = false;
        } else if (std.mem.eql(u8, arg, "--no-extra-boolean-cast=off")) {
            options.no_extra_boolean_cast = false;
        } else if (std.mem.eql(u8, arg, "--no-floating-decimal=off")) {
            options.no_floating_decimal = false;
        } else if (std.mem.eql(u8, arg, "--no-fallthrough=off")) {
            options.no_fallthrough = false;
        } else if (std.mem.eql(u8, arg, "--no-for-in=off")) {
            options.no_for_in = false;
        } else if (std.mem.eql(u8, arg, "--no-func-assign=off")) {
            options.no_func_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-global-assign=off")) {
            options.no_global_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-global-is-finite=off")) {
            options.no_global_is_finite = false;
        } else if (std.mem.eql(u8, arg, "--no-global-is-nan=off")) {
            options.no_global_is_nan = false;
        } else if (std.mem.eql(u8, arg, "--no-implicit-coercion=off")) {
            options.no_implicit_coercion = false;
        } else if (std.mem.eql(u8, arg, "--no-implied-eval=off")) {
            options.no_implied_eval = false;
        } else if (std.mem.eql(u8, arg, "--no-import-assign=off")) {
            options.no_import_assign = false;
        } else if (std.mem.eql(u8, arg, "--alipay-ant-disallow-typos=off")) {
            options.alipay_ant_disallow_typos = false;
        } else if (std.mem.eql(u8, arg, "--alipay-ant-exhaustive-deps=off")) {
            options.alipay_ant_exhaustive_deps = false;
        } else if (std.mem.eql(u8, arg, "--alipay-ant-no-import-src=off")) {
            options.alipay_ant_no_import_src = false;
        } else if (std.mem.eql(u8, arg, "--alipay-ant-no-phantom-dependencies=off")) {
            options.alipay_ant_no_phantom_dependencies = false;
        } else if (std.mem.eql(u8, arg, "--alipay-ant-no-spread-params=off")) {
            options.alipay_ant_no_spread_params = false;
        } else if (std.mem.eql(u8, arg, "--alipay-spmlint-use-labeled-spm=off")) {
            options.alipay_spmlint_use_labeled_spm = false;
        } else if (std.mem.eql(u8, arg, "--alipay-spmlint-valid-manual-click=off")) {
            options.alipay_spmlint_valid_manual_click = false;
        } else if (std.mem.eql(u8, arg, "--alipay-spmlint-valid-manual-expo=off")) {
            options.alipay_spmlint_valid_manual_expo = false;
        } else if (std.mem.eql(u8, arg, "--alipay-spmlint-valid-manual-param=off")) {
            options.alipay_spmlint_valid_manual_param = false;
        } else if (std.mem.eql(u8, arg, "--alipay-spmlint-valid-manual-pv=off")) {
            options.alipay_spmlint_valid_manual_pv = false;
        } else if (std.mem.eql(u8, arg, "--import-default=off")) {
            options.import_default = false;
        } else if (std.mem.eql(u8, arg, "--import-export=off")) {
            options.import_export = false;
        } else if (std.mem.eql(u8, arg, "--import-first=off")) {
            options.import_first = false;
        } else if (std.mem.eql(u8, arg, "--import-named=off")) {
            options.import_named = false;
        } else if (std.mem.eql(u8, arg, "--import-namespace=off")) {
            options.import_namespace = false;
        } else if (std.mem.eql(u8, arg, "--import-newline-after-import=off")) {
            options.import_newline_after_import = false;
        } else if (std.mem.eql(u8, arg, "--import-no-amd=off")) {
            options.import_no_amd = false;
        } else if (std.mem.eql(u8, arg, "--import-no-cycle=off")) {
            options.import_no_cycle = false;
        } else if (std.mem.eql(u8, arg, "--import-no-duplicates=off")) {
            options.import_no_duplicates = false;
        } else if (std.mem.eql(u8, arg, "--import-no-named-as-default=off")) {
            options.import_no_named_as_default = false;
        } else if (std.mem.eql(u8, arg, "--import-no-named-as-default-member=off")) {
            options.import_no_named_as_default_member = false;
        } else if (std.mem.eql(u8, arg, "--import-no-unresolved=off")) {
            options.import_no_unresolved = false;
        } else if (std.mem.eql(u8, arg, "--import-no-self-import=off")) {
            options.import_no_self_import = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-alt-text=off")) {
            options.jsx_a11y_alt_text = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-anchor-has-content=off")) {
            options.jsx_a11y_anchor_has_content = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-aria-props=off")) {
            options.jsx_a11y_aria_props = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-aria-proptypes=off")) {
            options.jsx_a11y_aria_proptypes = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-aria-role=off")) {
            options.jsx_a11y_aria_role = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-aria-unsupported-elements=off")) {
            options.jsx_a11y_aria_unsupported_elements = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-iframe-has-title=off")) {
            options.jsx_a11y_iframe_has_title = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-img-redundant-alt=off")) {
            options.jsx_a11y_img_redundant_alt = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-no-access-key=off")) {
            options.jsx_a11y_no_access_key = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-no-distracting-elements=off")) {
            options.jsx_a11y_no_distracting_elements = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-role-has-required-aria-props=off")) {
            options.jsx_a11y_role_has_required_aria_props = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-role-supports-aria-props=off")) {
            options.jsx_a11y_role_supports_aria_props = false;
        } else if (std.mem.eql(u8, arg, "--jsx-a11y-scope=off")) {
            options.jsx_a11y_scope = false;
        } else if (std.mem.eql(u8, arg, "--no-invalid-regexp=off")) {
            options.no_invalid_regexp = false;
        } else if (std.mem.eql(u8, arg, "--no-irregular-whitespace=off")) {
            options.no_irregular_whitespace = false;
        } else if (std.mem.eql(u8, arg, "--no-inline-comments=off")) {
            options.no_inline_comments = false;
        } else if (std.mem.eql(u8, arg, "--no-inner-declarations=off")) {
            options.no_inner_declarations = false;
        } else if (std.mem.eql(u8, arg, "--no-iterator=off")) {
            options.no_iterator = false;
        } else if (std.mem.eql(u8, arg, "--no-label-var=off")) {
            options.no_label_var = false;
        } else if (std.mem.eql(u8, arg, "--no-labels=off")) {
            options.no_labels = false;
        } else if (std.mem.eql(u8, arg, "--no-lone-blocks=off")) {
            options.no_lone_blocks = false;
        } else if (std.mem.eql(u8, arg, "--no-lonely-if=off")) {
            options.no_lonely_if = false;
        } else if (std.mem.eql(u8, arg, "--no-loop-func=off")) {
            options.no_loop_func = false;
        } else if (std.mem.eql(u8, arg, "--no-loss-of-precision=off")) {
            options.no_loss_of_precision = false;
        } else if (std.mem.eql(u8, arg, "--no-multi-str=off")) {
            options.no_multi_str = false;
        } else if (std.mem.eql(u8, arg, "--no-multi-assign=off")) {
            options.no_multi_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-multi-spaces=off")) {
            options.no_multi_spaces = false;
        } else if (std.mem.eql(u8, arg, "--no-mixed-spaces-and-tabs=off")) {
            options.no_mixed_spaces_and_tabs = false;
        } else if (std.mem.eql(u8, arg, "--no-misleading-character-class=off")) {
            options.no_misleading_character_class = false;
        } else if (std.mem.eql(u8, arg, "--no-multiple-empty-lines=off")) {
            options.no_multiple_empty_lines = false;
        } else if (std.mem.eql(u8, arg, "--no-nonoctal-decimal-escape=off")) {
            options.no_nonoctal_decimal_escape = false;
        } else if (std.mem.eql(u8, arg, "--no-new=off")) {
            options.no_new = false;
        } else if (std.mem.eql(u8, arg, "--no-nested-ternary=off")) {
            options.no_nested_ternary = false;
        } else if (std.mem.eql(u8, arg, "--no-negated-condition=off")) {
            options.no_negated_condition = false;
        } else if (std.mem.eql(u8, arg, "--no-new-native-nonconstructor=off")) {
            options.no_new_native_nonconstructor = false;
        } else if (std.mem.eql(u8, arg, "--no-new-func=off")) {
            options.no_new_func = false;
        } else if (std.mem.eql(u8, arg, "--no-new-require=off")) {
            options.no_new_require = false;
        } else if (std.mem.eql(u8, arg, "--no-obj-calls=off")) {
            options.no_obj_calls = false;
        } else if (std.mem.eql(u8, arg, "--no-new-object=off")) {
            options.no_new_object = false;
        } else if (std.mem.eql(u8, arg, "--no-new-symbol=off")) {
            options.no_new_symbol = false;
        } else if (std.mem.eql(u8, arg, "--no-new-wrappers=off")) {
            options.no_new_wrappers = false;
        } else if (std.mem.eql(u8, arg, "--no-octal=off")) {
            options.no_octal = false;
        } else if (std.mem.eql(u8, arg, "--no-octal-escape=off")) {
            options.no_octal_escape = false;
        } else if (std.mem.eql(u8, arg, "--no-object-constructor=off")) {
            options.no_object_constructor = false;
        } else if (std.mem.eql(u8, arg, "--no-param-reassign=off")) {
            options.no_param_reassign = false;
        } else if (std.mem.eql(u8, arg, "--no-path-concat=off")) {
            options.no_path_concat = false;
        } else if (std.mem.eql(u8, arg, "--no-plusplus=off")) {
            options.no_plusplus = false;
        } else if (std.mem.eql(u8, arg, "--no-promise-executor-return=off")) {
            options.no_promise_executor_return = false;
        } else if (std.mem.eql(u8, arg, "--no-proto=off")) {
            options.no_proto = false;
        } else if (std.mem.eql(u8, arg, "--no-process-env=off")) {
            options.no_process_env = false;
        } else if (std.mem.eql(u8, arg, "--no-process-exit=off")) {
            options.no_process_exit = false;
        } else if (std.mem.eql(u8, arg, "--no-prototype-builtins=off")) {
            options.no_prototype_builtins = false;
        } else if (std.mem.eql(u8, arg, "--no-redeclare=off")) {
            options.no_redeclare = false;
        } else if (std.mem.eql(u8, arg, "--no-regex-spaces=off")) {
            options.no_regex_spaces = false;
        } else if (std.mem.eql(u8, arg, "--no-return-await=off")) {
            options.no_return_await = false;
        } else if (std.mem.eql(u8, arg, "--no-return-assign=off")) {
            options.no_return_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-return=off")) {
            options.no_useless_return = false;
        } else if (std.mem.eql(u8, arg, "--no-script-url=off")) {
            options.no_script_url = false;
        } else if (std.mem.eql(u8, arg, "--no-self-assign=off")) {
            options.no_self_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-self-compare=off")) {
            options.no_self_compare = false;
        } else if (std.mem.eql(u8, arg, "--no-setter-return=off")) {
            options.no_setter_return = false;
        } else if (std.mem.eql(u8, arg, "--no-shadow=off")) {
            options.no_shadow = false;
        } else if (std.mem.eql(u8, arg, "--no-shadow-restricted-names=off")) {
            options.no_shadow_restricted_names = false;
        } else if (std.mem.eql(u8, arg, "--no-sequences=off")) {
            options.no_sequences = false;
        } else if (std.mem.eql(u8, arg, "--no-sparse-arrays=off")) {
            options.no_sparse_arrays = false;
        } else if (std.mem.eql(u8, arg, "--no-ternary=off")) {
            options.no_ternary = false;
        } else if (std.mem.eql(u8, arg, "--no-template-curly-in-string=off")) {
            options.no_template_curly_in_string = false;
        } else if (std.mem.eql(u8, arg, "--no-throw-literal=off")) {
            options.no_throw_literal = false;
        } else if (std.mem.eql(u8, arg, "--no-this-before-super=off")) {
            options.no_this_before_super = false;
        } else if (std.mem.eql(u8, arg, "--no-tabs=off")) {
            options.no_tabs = false;
        } else if (std.mem.eql(u8, arg, "--no-trailing-spaces=off")) {
            options.no_trailing_spaces = false;
        } else if (std.mem.eql(u8, arg, "--no-unreachable=off")) {
            options.no_unreachable = false;
        } else if (std.mem.eql(u8, arg, "--no-undef-init=off")) {
            options.no_undef_init = false;
        } else if (std.mem.eql(u8, arg, "--unicode-bom=off")) {
            options.unicode_bom = false;
        } else if (std.mem.eql(u8, arg, "--no-unneeded-ternary=off")) {
            options.no_unneeded_ternary = false;
        } else if (std.mem.eql(u8, arg, "--no-unused-labels=off")) {
            options.no_unused_labels = false;
        } else if (std.mem.eql(u8, arg, "--no-unsafe-finally=off")) {
            options.no_unsafe_finally = false;
        } else if (std.mem.eql(u8, arg, "--no-unsafe-negation=off")) {
            options.no_unsafe_negation = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-computed-key=off")) {
            options.no_useless_computed_key = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-call=off")) {
            options.no_useless_call = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-concat=off")) {
            options.no_useless_concat = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-constructor=off")) {
            options.no_useless_constructor = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-catch=off")) {
            options.no_useless_catch = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-escape=off")) {
            options.no_useless_escape = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-rename=off")) {
            options.no_useless_rename = false;
        } else if (std.mem.eql(u8, arg, "--no-unused-expressions=off")) {
            options.no_unused_expressions = false;
        } else if (std.mem.eql(u8, arg, "--no-warning-comments=off")) {
            options.no_warning_comments = false;
        } else if (std.mem.eql(u8, arg, "--no-void=off")) {
            options.no_void = false;
        } else if (std.mem.eql(u8, arg, "--no-with=off")) {
            options.no_with = false;
        } else if (std.mem.eql(u8, arg, "--no-var=off")) {
            options.no_var = false;
        } else if (std.mem.eql(u8, arg, "--one-var=off")) {
            options.one_var = false;
        } else if (std.mem.eql(u8, arg, "--object-shorthand=off")) {
            options.object_shorthand = false;
        } else if (std.mem.eql(u8, arg, "--operator-assignment=off")) {
            options.operator_assignment = false;
        } else if (std.mem.eql(u8, arg, "--eqeqeq=off")) {
            options.eqeqeq = false;
        } else if (std.mem.eql(u8, arg, "--use-isnan=off")) {
            options.use_isnan = false;
        } else if (std.mem.eql(u8, arg, "--no-unused-vars=off")) {
            options.no_unused_vars = false;
        } else if (std.mem.eql(u8, arg, "--no-use-before-define=off")) {
            options.no_use_before_define = false;
        } else if (std.mem.eql(u8, arg, "--no-undef=off")) {
            options.no_undef = false;
        } else if (std.mem.eql(u8, arg, "--prefer-const=off")) {
            options.prefer_const = false;
        } else if (std.mem.eql(u8, arg, "--prefer-exponentiation-operator=off")) {
            options.prefer_exponentiation_operator = false;
        } else if (std.mem.eql(u8, arg, "--prefer-promise-reject-errors=off")) {
            options.prefer_promise_reject_errors = false;
        } else if (std.mem.eql(u8, arg, "--prefer-destructuring=off")) {
            options.prefer_destructuring = false;
        } else if (std.mem.eql(u8, arg, "--prefer-regex-literals=off")) {
            options.prefer_regex_literals = false;
        } else if (std.mem.eql(u8, arg, "--prefer-rest-params=off")) {
            options.prefer_rest_params = false;
        } else if (std.mem.eql(u8, arg, "--prefer-spread=off")) {
            options.prefer_spread = false;
        } else if (std.mem.eql(u8, arg, "--prefer-template=off")) {
            options.prefer_template = false;
        } else if (std.mem.eql(u8, arg, "--react-default-props-match-prop-types=off")) {
            options.react_default_props_match_prop_types = false;
        } else if (std.mem.eql(u8, arg, "--react-display-name=off")) {
            options.react_display_name = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-boolean-value=off")) {
            options.react_jsx_boolean_value = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-filename-extension=off")) {
            options.react_jsx_filename_extension = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-no-duplicate-props=off")) {
            options.react_jsx_no_duplicate_props = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-no-comment-textnodes=off")) {
            options.react_jsx_no_comment_textnodes = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-no-bind=off")) {
            options.react_jsx_no_bind = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-key=off")) {
            options.react_jsx_key = false;
        } else if (std.mem.eql(u8, arg, "--react-button-has-type=off")) {
            options.react_button_has_type = false;
        } else if (std.mem.eql(u8, arg, "--react-require-render-return=off")) {
            options.react_require_render_return = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-no-target-blank=off")) {
            options.react_jsx_no_target_blank = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-no-undef=off")) {
            options.react_jsx_no_undef = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-pascal-case=off")) {
            options.react_jsx_pascal_case = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-uses-react=off")) {
            options.react_jsx_uses_react = false;
        } else if (std.mem.eql(u8, arg, "--react-jsx-uses-vars=off")) {
            options.react_jsx_uses_vars = false;
        } else if (std.mem.eql(u8, arg, "--react-no-danger=off")) {
            options.react_no_danger = false;
        } else if (std.mem.eql(u8, arg, "--react-no-danger-with-children=off")) {
            options.react_no_danger_with_children = false;
        } else if (std.mem.eql(u8, arg, "--react-no-access-state-in-setstate=off")) {
            options.react_no_access_state_in_setstate = false;
        } else if (std.mem.eql(u8, arg, "--react-no-deprecated=off")) {
            options.react_no_deprecated = false;
        } else if (std.mem.eql(u8, arg, "--react-forbid-prop-types=off")) {
            options.react_forbid_prop_types = false;
        } else if (std.mem.eql(u8, arg, "--react-no-array-index-key=off")) {
            options.react_no_array_index_key = false;
        } else if (std.mem.eql(u8, arg, "--react-no-children-prop=off")) {
            options.react_no_children_prop = false;
        } else if (std.mem.eql(u8, arg, "--react-no-find-dom-node=off")) {
            options.react_no_find_dom_node = false;
        } else if (std.mem.eql(u8, arg, "--react-no-is-mounted=off")) {
            options.react_no_is_mounted = false;
        } else if (std.mem.eql(u8, arg, "--react-no-multi-comp=off")) {
            options.react_no_multi_comp = false;
        } else if (std.mem.eql(u8, arg, "--react-no-redundant-should-component-update=off")) {
            options.react_no_redundant_should_component_update = false;
        } else if (std.mem.eql(u8, arg, "--react-no-render-return-value=off")) {
            options.react_no_render_return_value = false;
        } else if (std.mem.eql(u8, arg, "--react-no-will-update-set-state=off")) {
            options.react_no_will_update_set_state = false;
        } else if (std.mem.eql(u8, arg, "--react-no-this-in-sfc=off")) {
            options.react_no_this_in_sfc = false;
        } else if (std.mem.eql(u8, arg, "--react-no-typos=off")) {
            options.react_no_typos = false;
        } else if (std.mem.eql(u8, arg, "--react-no-unknown-property=off")) {
            options.react_no_unknown_property = false;
        } else if (std.mem.eql(u8, arg, "--react-prop-types=off")) {
            options.react_prop_types = false;
        } else if (std.mem.eql(u8, arg, "--react-no-unused-prop-types=off")) {
            options.react_no_unused_prop_types = false;
        } else if (std.mem.eql(u8, arg, "--react-no-unused-state=off")) {
            options.react_no_unused_state = false;
        } else if (std.mem.eql(u8, arg, "--react-no-string-refs=off")) {
            options.react_no_string_refs = false;
        } else if (std.mem.eql(u8, arg, "--react-no-unescaped-entities=off")) {
            options.react_no_unescaped_entities = false;
        } else if (std.mem.eql(u8, arg, "--react-prefer-es6-class=off")) {
            options.react_prefer_es6_class = false;
        } else if (std.mem.eql(u8, arg, "--react-self-closing-comp=off")) {
            options.react_self_closing_comp = false;
        } else if (std.mem.eql(u8, arg, "--react-style-prop-object=off")) {
            options.react_style_prop_object = false;
        } else if (std.mem.eql(u8, arg, "--react-void-dom-elements-no-children=off")) {
            options.react_void_dom_elements_no_children = false;
        } else if (std.mem.eql(u8, arg, "--react-hooks-rules-of-hooks=off")) {
            options.react_hooks_rules_of_hooks = false;
        } else if (std.mem.eql(u8, arg, "--radix=off")) {
            options.radix = false;
        } else if (std.mem.eql(u8, arg, "--require-atomic-updates=off")) {
            options.require_atomic_updates = false;
        } else if (std.mem.eql(u8, arg, "--require-yield=off")) {
            options.require_yield = false;
        } else if (std.mem.eql(u8, arg, "--spaced-comment=off")) {
            options.spaced_comment = false;
        } else if (std.mem.eql(u8, arg, "--symbol-description=off")) {
            options.symbol_description = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-adjacent-overload-signatures=off")) {
            options.typescript_eslint_adjacent_overload_signatures = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-array-type=off")) {
            options.typescript_eslint_array_type = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-class-literal-property-style=off")) {
            options.typescript_eslint_class_literal_property_style = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-consistent-type-assertions=off")) {
            options.typescript_eslint_consistent_type_assertions = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-consistent-type-definitions=off")) {
            options.typescript_eslint_consistent_type_definitions = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-dot-notation=off")) {
            options.typescript_eslint_dot_notation = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-array-constructor=off")) {
            options.typescript_eslint_no_array_constructor = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-ban-types=off")) {
            options.typescript_eslint_ban_types = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-ban-ts-comment=off")) {
            options.typescript_eslint_ban_ts_comment = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-ban-tslint-comment=off")) {
            options.typescript_eslint_ban_tslint_comment = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-explicit-member-accessibility=off")) {
            options.typescript_eslint_explicit_member_accessibility = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-member-ordering=off")) {
            options.typescript_eslint_member_ordering = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-method-signature-style=off")) {
            options.typescript_eslint_method_signature_style = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-confusing-non-null-assertion=off")) {
            options.typescript_eslint_no_confusing_non_null_assertion = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-dupe-class-members=off")) {
            options.typescript_eslint_no_dupe_class_members = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-empty-function=off")) {
            options.typescript_eslint_no_empty_function = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-empty-interface=off")) {
            options.typescript_eslint_no_empty_interface = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-extra-semi=off")) {
            options.typescript_eslint_no_extra_semi = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-extra-non-null-assertion=off")) {
            options.typescript_eslint_no_extra_non_null_assertion = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-duplicate-enum-values=off")) {
            options.typescript_eslint_no_duplicate_enum_values = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-inferrable-types=off")) {
            options.typescript_eslint_no_inferrable_types = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-invalid-void-type=off")) {
            options.typescript_eslint_no_invalid_void_type = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-loss-of-precision=off")) {
            options.typescript_eslint_no_loss_of_precision = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-loop-func=off")) {
            options.typescript_eslint_no_loop_func = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-misused-new=off")) {
            options.typescript_eslint_no_misused_new = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-namespace=off")) {
            options.typescript_eslint_no_namespace = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-non-null-asserted-optional-chain=off")) {
            options.typescript_eslint_no_non_null_asserted_optional_chain = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-redeclare=off")) {
            options.typescript_eslint_no_redeclare = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-require-imports=off")) {
            options.typescript_eslint_no_require_imports = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-shadow=off")) {
            options.typescript_eslint_no_shadow = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-this-alias=off")) {
            options.typescript_eslint_no_this_alias = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-unsafe-declaration-merging=off")) {
            options.typescript_eslint_no_unsafe_declaration_merging = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-triple-slash-reference=off")) {
            options.typescript_eslint_triple_slash_reference = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-typedef=off")) {
            options.typescript_eslint_typedef = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-unified-signatures=off")) {
            options.typescript_eslint_unified_signatures = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-unnecessary-parameter-property-assignment=off")) {
            options.typescript_eslint_no_unnecessary_parameter_property_assignment = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-unnecessary-type-constraint=off")) {
            options.typescript_eslint_no_unnecessary_type_constraint = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-useless-constructor=off")) {
            options.typescript_eslint_no_useless_constructor = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-useless-empty-export=off")) {
            options.typescript_eslint_no_useless_empty_export = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-unused-expressions=off")) {
            options.typescript_eslint_no_unused_expressions = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-unused-vars=off")) {
            options.typescript_eslint_no_unused_vars = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-use-before-define=off")) {
            options.typescript_eslint_no_use_before_define = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-var-requires=off")) {
            options.typescript_eslint_no_var_requires = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-no-wrapper-object-types=off")) {
            options.typescript_eslint_no_wrapper_object_types = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-prefer-as-const=off")) {
            options.typescript_eslint_prefer_as_const = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-prefer-namespace-keyword=off")) {
            options.typescript_eslint_prefer_namespace_keyword = false;
        } else if (std.mem.eql(u8, arg, "--typescript-eslint-restrict-plus-operands=off")) {
            options.typescript_eslint_restrict_plus_operands = false;
        } else if (std.mem.eql(u8, arg, "--valid-typeof=off")) {
            options.valid_typeof = false;
        } else if (std.mem.eql(u8, arg, "--semantic-errors=off")) {
            options.parser_semantic_errors = false;
        } else if (std.mem.eql(u8, arg, "--yoda=off")) {
            options.yoda = false;
        } else {
            try targets.append(allocator, arg);
        }
    }

    if (targets.items.len == 0) {
        try targets.append(allocator, ".");
    }

    var files: std.ArrayList([]const u8) = .empty;
    defer {
        for (files.items) |file| {
            allocator.free(file);
        }
        files.deinit(allocator);
    }

    var json_diagnostics: JsonDiagnosticList = .empty;
    defer freeJsonDiagnostics(allocator, &json_diagnostics);
    const json_diagnostics_ptr: ?*JsonDiagnosticList = if (output_format == .json) &json_diagnostics else null;

    var stats = Stats{};
    for (targets.items) |target| {
        try collectLintablePaths(allocator, io, target, &files, &stats, json_diagnostics_ptr);
    }

    if (output_format == .json) {
        try lintFilesJson(allocator, io, files.items, options, &stats, &json_diagnostics);
        try writeJsonReport(io, stats, json_diagnostics.items);
    } else {
        try lintFiles(allocator, io, files.items, options, thread_count_override, &stats);

        std.debug.print("{d} file(s) checked, {d} diagnostic(s)\n", .{
            stats.files,
            stats.diagnostics,
        });
    }

    if (stats.errors > 0 or stats.diagnostics > 0) {
        std.process.exit(1);
    }
}

fn hasHelpArg(args: []const []const u8) bool {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) return true;
    }
    return false;
}

const ConfigArgs = struct {
    enabled: bool = true,
    path: ?[]const u8 = null,
};

fn parseConfigArgs(args: []const []const u8) ConfigArgs {
    var config = ConfigArgs{};
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--no-config")) {
            config.enabled = false;
            config.path = null;
        } else if (std.mem.startsWith(u8, arg, "--config=")) {
            config.enabled = true;
            config.path = arg["--config=".len..];
            if (config.path.?.len == 0) {
                std.debug.print("utoo-lint: --config requires a path\n", .{});
                std.process.exit(2);
            }
        }
    }
    return config;
}

fn findDefaultConfig(io: std.Io) ?[]const u8 {
    const cwd = std.Io.Dir.cwd();
    const candidates = [_][]const u8{
        "utoo.json",
        "utoo-lint.json",
    };

    for (candidates) |path| {
        const stat = cwd.statFile(io, path, .{}) catch continue;
        if (stat.kind == .file) return path;
    }
    return null;
}

fn parseOutputFormat(value: []const u8) ?OutputFormat {
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return null;
}

fn loadConfigFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    explicit: bool,
    options: *lint.Options,
) !void {
    const source = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_config_file_size)) catch |err| {
        if (explicit) {
            std.debug.print("utoo-lint: unable to read config {s}: {s}\n", .{ path, @errorName(err) });
            std.process.exit(2);
        }
        return;
    };
    defer allocator.free(source);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{}) catch |err| {
        std.debug.print("utoo-lint: invalid config {s}: {s}\n", .{ path, @errorName(err) });
        std.process.exit(2);
    };
    defer parsed.deinit();

    const root = switch (parsed.value) {
        .object => |object| object,
        else => {
            std.debug.print("utoo-lint: config {s} must be a JSON object\n", .{path});
            std.process.exit(2);
        },
    };

    const rules_value = root.get("rules") orelse return;
    const rules = switch (rules_value) {
        .object => |object| object,
        else => {
            std.debug.print("utoo-lint: config {s} field \"rules\" must be an object\n", .{path});
            std.process.exit(2);
        },
    };

    var iter = rules.iterator();
    while (iter.next()) |entry| {
        options.setByRuleConfigValue(entry.key_ptr.*, entry.value_ptr.*) catch |err| {
            std.debug.print(
                "utoo-lint: invalid config {s} rule {s}: {s}\n",
                .{ path, entry.key_ptr.*, @errorName(err) },
            );
            std.process.exit(2);
        };
    }
}

fn collectLintablePaths(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    files: *std.ArrayList([]const u8),
    stats: *Stats,
    json_diagnostics: ?*JsonDiagnosticList,
) !void {
    const cwd = std.Io.Dir.cwd();
    const stat = cwd.statFile(io, path, .{}) catch |err| {
        if (json_diagnostics) |diagnostics| {
            const message = try std.fmt.allocPrint(allocator, "unable to stat path: {s}", .{@errorName(err)});
            defer allocator.free(message);
            try appendJsonDiagnostic(allocator, diagnostics, path, 0, 0, "error", message, "io");
        } else {
            std.debug.print("{s}: unable to stat path: {s}\n", .{ path, @errorName(err) });
        }
        stats.errors += 1;
        stats.diagnostics += 1;
        return;
    };

    switch (stat.kind) {
        .file => {
            if (lint.isLintablePath(path)) {
                try files.append(allocator, try allocator.dupe(u8, path));
            }
        },
        .directory => try collectLintableDirectory(allocator, io, path, files, stats, json_diagnostics),
        else => {},
    }
}

fn parseEnabledRules(value: []const u8, options: *lint.Options) void {
    if (value.len == 0) {
        std.debug.print("utoo-lint: --rules requires a comma-separated rule list\n", .{});
        std.process.exit(2);
    }

    var iter = std.mem.splitScalar(u8, value, ',');
    while (iter.next()) |raw_rule| {
        const rule = std.mem.trim(u8, raw_rule, " \t\r\n");
        if (rule.len == 0) {
            std.debug.print("utoo-lint: --rules contains an empty rule name\n", .{});
            std.process.exit(2);
        }
        if (!options.setByCliName(rule, true)) {
            std.debug.print("utoo-lint: unknown rule in --rules: {s}\n", .{rule});
            std.process.exit(2);
        }
    }
}

fn collectLintableDirectory(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    files: *std.ArrayList([]const u8),
    stats: *Stats,
    json_diagnostics: ?*JsonDiagnosticList,
) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    defer dir.close(io);

    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (shouldSkipDirectoryEntry(entry.name)) continue;

        const child_path = try std.fs.path.join(allocator, &.{ path, entry.name });
        defer allocator.free(child_path);

        switch (entry.kind) {
            .file => {
                if (lint.isLintablePath(child_path)) {
                    try files.append(allocator, try allocator.dupe(u8, child_path));
                }
            },
            .directory => try collectLintableDirectory(allocator, io, child_path, files, stats, json_diagnostics),
            else => {},
        }
    }
}

fn lintFiles(
    allocator: std.mem.Allocator,
    io: std.Io,
    files: []const []const u8,
    options: lint.Options,
    thread_count_override: ?usize,
    stats: *Stats,
) !void {
    if (files.len == 0) return;

    const worker_count = @min(files.len, thread_count_override orelse (std.Thread.getCpuCount() catch 1));
    if (worker_count <= 1) {
        for (files) |file| {
            try lintFile(std.heap.smp_allocator, io, file, options, stats, null);
        }
        return;
    }

    var queue = WorkQueue{
        .io = io,
        .files = files,
        .options = options,
    };

    const threads = try allocator.alloc(std.Thread, worker_count);
    defer allocator.free(threads);

    const results = try allocator.alloc(WorkerResult, worker_count);
    defer allocator.free(results);
    for (results) |*result| {
        result.* = .{};
    }

    var spawned: usize = 0;
    errdefer {
        for (threads[0..spawned]) |thread| {
            thread.join();
        }
    }

    for (threads, 0..) |*thread, index| {
        thread.* = try std.Thread.spawn(.{}, lintWorker, .{ &queue, &results[index] });
        spawned += 1;
    }

    for (threads) |thread| {
        thread.join();
    }

    var worker_err: ?anyerror = null;
    for (results) |result| {
        stats.add(result.stats);
        if (worker_err == null) {
            worker_err = result.err;
        }
    }

    if (worker_err) |err| {
        return err;
    }
}

fn lintFilesJson(
    allocator: std.mem.Allocator,
    io: std.Io,
    files: []const []const u8,
    options: lint.Options,
    stats: *Stats,
    json_diagnostics: *JsonDiagnosticList,
) !void {
    for (files) |file| {
        try lintFileJson(allocator, io, file, options, stats, json_diagnostics);
    }
}

fn lintWorker(queue: *WorkQueue, result: *WorkerResult) void {
    while (true) {
        const index = queue.next_index.fetchAdd(1, .monotonic);
        if (index >= queue.files.len) return;

        lintFile(
            std.heap.smp_allocator,
            queue.io,
            queue.files[index],
            queue.options,
            &result.stats,
            &queue.print_mutex,
        ) catch |err| {
            result.err = err;
            return;
        };
    }
}

fn lintFileJson(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    options: lint.Options,
    stats: *Stats,
    json_diagnostics: *JsonDiagnosticList,
) !void {
    const source = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_file_size)) catch |err| {
        const message = try std.fmt.allocPrint(allocator, "unable to read file: {s}", .{@errorName(err)});
        defer allocator.free(message);
        try appendJsonDiagnostic(allocator, json_diagnostics, path, 0, 0, "error", message, "io");
        stats.errors += 1;
        stats.diagnostics += 1;
        return;
    };
    defer allocator.free(source);

    var result = try lint.lintSourceWithIo(allocator, io, source, path, options);
    defer result.deinit(allocator);

    stats.files += 1;

    for (result.diagnostics) |diagnostic| {
        const position = lint.offsetToLineColumn(source, diagnostic.span.start);
        try appendJsonDiagnostic(
            allocator,
            json_diagnostics,
            path,
            position.line,
            position.column,
            diagnostic.severity.toString(),
            diagnostic.message,
            diagnostic.rule_id,
        );

        stats.diagnostics += 1;
        if (diagnostic.severity == .@"error") {
            stats.errors += 1;
        }
    }
}

fn lintFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    options: lint.Options,
    stats: *Stats,
    print_mutex: ?*std.Io.Mutex,
) !void {
    const source = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_file_size)) catch |err| {
        printLocked(io, print_mutex, "{s}: unable to read file: {s}\n", .{ path, @errorName(err) });
        stats.errors += 1;
        stats.diagnostics += 1;
        return;
    };
    defer allocator.free(source);

    var result = try lint.lintSourceWithIo(allocator, io, source, path, options);
    defer result.deinit(allocator);

    stats.files += 1;

    for (result.diagnostics) |diagnostic| {
        const position = lint.offsetToLineColumn(source, diagnostic.span.start);
        printLocked(io, print_mutex, "{s}:{d}:{d}: {s}: {s} [{s}]\n", .{
            path,
            position.line,
            position.column,
            diagnostic.severity.toString(),
            diagnostic.message,
            diagnostic.rule_id,
        });

        stats.diagnostics += 1;
        if (diagnostic.severity == .@"error") {
            stats.errors += 1;
        }
    }
}

fn appendJsonDiagnostic(
    allocator: std.mem.Allocator,
    diagnostics: *JsonDiagnosticList,
    path: []const u8,
    line: usize,
    column: usize,
    severity: []const u8,
    message: []const u8,
    rule_id: []const u8,
) !void {
    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);

    const owned_message = try allocator.dupe(u8, message);
    errdefer allocator.free(owned_message);

    const owned_rule_id = try allocator.dupe(u8, rule_id);
    errdefer allocator.free(owned_rule_id);

    try diagnostics.append(allocator, .{
        .@"filePath" = owned_path,
        .line = line,
        .column = column,
        .severity = severity,
        .message = owned_message,
        .@"ruleId" = owned_rule_id,
    });
}

fn freeJsonDiagnostics(allocator: std.mem.Allocator, diagnostics: *JsonDiagnosticList) void {
    for (diagnostics.items) |diagnostic| {
        allocator.free(diagnostic.@"filePath");
        allocator.free(diagnostic.message);
        allocator.free(diagnostic.@"ruleId");
    }
    diagnostics.deinit(allocator);
}

fn writeJsonReport(io: std.Io, stats: Stats, diagnostics: []const JsonDiagnostic) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try std.json.Stringify.value(JsonReport{
        .files = stats.files,
        .diagnostics = diagnostics,
    }, .{}, stdout);
    try stdout.writeByte('\n');
    try stdout.flush();
}

fn printLocked(
    io: std.Io,
    mutex: ?*std.Io.Mutex,
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (mutex) |m| {
        m.lockUncancelable(io);
        defer m.unlock(io);
    }
    std.debug.print(fmt, args);
}

fn shouldSkipDirectoryEntry(name: []const u8) bool {
    return std.mem.eql(u8, name, ".git") or
        std.mem.eql(u8, name, ".zig-cache") or
        std.mem.eql(u8, name, "node_modules") or
        std.mem.eql(u8, name, "vendor") or
        std.mem.eql(u8, name, "zig-out");
}

fn printHelp() void {
    std.debug.print(
        \\Usage:
        \\  utoo-lint [options] [file-or-directory ...]
        \\
        \\Options:
        \\  --config=PATH            Read configuration from PATH
        \\  --no-config              Do not read utoo.json or utoo-lint.json
        \\  --format=text|json       Select diagnostic output format
        \\  --json                   Alias for --format=json
        \\  --threads=N              Number of worker threads to use
        \\  --rules=a,b,c            Enable only the comma-separated rule list
        \\  --array-callback-return=off Disable array-callback-return
        \\  --block-scoped-var=off   Disable block-scoped-var
        \\  --constructor-super=off  Disable constructor-super
        \\  --curly=off              Disable curly
        \\  --dot-notation=off       Disable dot-notation
        \\  --default-case=off        Disable default-case
        \\  --default-case-last=off   Disable default-case-last
        \\  --eol-last=off            Disable eol-last
        \\  --for-direction=off       Disable for-direction
        \\  --getter-return=off       Disable getter-return
        \\  --guard-for-in=off        Disable guard-for-in
        \\  --linebreak-style=off     Disable linebreak-style
        \\  --new-cap=off             Disable new-cap
        \\  --new-parens=off          Disable new-parens
        \\  --no-async-promise-executor=off Disable no-async-promise-executor
        \\  --no-array-constructor=off Disable no-array-constructor
        \\  --no-await-in-loop=off    Disable no-await-in-loop
        \\  --no-alert=off            Disable no-alert
        \\  --no-bitwise=off          Disable no-bitwise
        \\  --no-buffer-constructor=off Disable no-buffer-constructor
        \\  --no-caller=off           Disable no-caller
        \\  --no-case-declarations=off Disable no-case-declarations
        \\  --no-class-assign=off     Disable no-class-assign
        \\  --no-cond-assign=off      Disable no-cond-assign
        \\  --no-compare-neg-zero=off Disable no-compare-neg-zero
        \\  --no-constant-condition=off Disable no-constant-condition
        \\  --no-const-assign=off    Disable no-const-assign
        \\  --no-control-regex=off   Disable no-control-regex
        \\  --no-comma-operator=off   Disable no-comma-operator
        \\  --no-console=off          Disable no-console
        \\  --no-continue=off         Disable no-continue
        \\  --no-constructor-return=off Disable no-constructor-return
        \\  --no-debugger=off         Disable no-debugger
        \\  --no-dupe-else-if=off     Disable no-dupe-else-if
        \\  --no-duplicate-case=off   Disable no-duplicate-case
        \\  --no-duplicate-imports=off Disable no-duplicate-imports
        \\  --no-dupe-args=off        Disable no-dupe-args
        \\  --no-dupe-class-members=off Disable no-dupe-class-members
        \\  --no-dupe-keys=off        Disable no-dupe-keys
        \\  --no-delete-var=off       Disable no-delete-var
        \\  --no-div-regex=off        Disable no-div-regex
        \\  --no-empty=off            Disable no-empty
        \\  --no-empty-block-statements=off Disable no-empty-block-statements
        \\  --no-empty-character-class=off Disable no-empty-character-class
        \\  --no-empty-function=off Disable no-empty-function
        \\  --no-empty-pattern=off  Disable no-empty-pattern
        \\  --no-empty-static-block=off Disable no-empty-static-block
        \\  --no-else-return=off    Disable no-else-return
        \\  --no-eq-null=off        Disable no-eq-null
        \\  --no-eval=off           Disable no-eval
        \\  --no-ex-assign=off      Disable no-ex-assign
        \\  --no-extend-native=off  Disable no-extend-native
        \\  --no-extra-bind=off     Disable no-extra-bind
        \\  --no-extra-label=off    Disable no-extra-label
        \\  --no-extra-semi=off      Disable no-extra-semi
        \\  --no-extra-boolean-cast=off Disable no-extra-boolean-cast
        \\  --no-floating-decimal=off Disable no-floating-decimal
        \\  --no-fallthrough=off      Disable no-fallthrough
        \\  --no-for-in=off           Disable no-for-in
        \\  --no-func-assign=off      Disable no-func-assign
        \\  --no-global-assign=off    Disable no-global-assign
        \\  --no-global-is-finite=off Disable no-global-is-finite
        \\  --no-global-is-nan=off    Disable no-global-is-nan
        \\  --no-implicit-coercion=off Disable no-implicit-coercion
        \\  --no-implied-eval=off      Disable no-implied-eval
        \\  --no-import-assign=off     Disable no-import-assign
        \\  --alipay-ant-disallow-typos=off Disable @alipay/ant/disallow-typos
        \\  --alipay-ant-exhaustive-deps=off Disable @alipay/ant/exhaustive-deps
        \\  --alipay-ant-no-import-src=off Disable @alipay/ant/no-import-src
        \\  --alipay-ant-no-phantom-dependencies=off Disable @alipay/ant/no-phantom-dependencies
        \\  --alipay-ant-no-spread-params=off Disable @alipay/ant/no-spread-params
        \\  --alipay-spmlint-use-labeled-spm=off Disable @alipay/spmLint/use-labeled-spm
        \\  --alipay-spmlint-valid-manual-click=off Disable @alipay/spmLint/valid-manual-click
        \\  --alipay-spmlint-valid-manual-expo=off Disable @alipay/spmLint/valid-manual-expo
        \\  --alipay-spmlint-valid-manual-param=off Disable @alipay/spmLint/valid-manual-param
        \\  --alipay-spmlint-valid-manual-pv=off Disable @alipay/spmLint/valid-manual-pv
        \\  --import-default=off      Disable import/default
        \\  --import-export=off       Disable import/export
        \\  --import-first=off         Disable import/first
        \\  --import-named=off        Disable import/named
        \\  --import-namespace=off    Disable import/namespace
        \\  --import-newline-after-import=off Disable import/newline-after-import
        \\  --import-no-amd=off        Disable import/no-amd
        \\  --import-no-cycle=off      Disable import/no-cycle
        \\  --import-no-duplicates=off Disable import/no-duplicates
        \\  --import-no-named-as-default=off Disable import/no-named-as-default
        \\  --import-no-named-as-default-member=off Disable import/no-named-as-default-member
        \\  --import-no-unresolved=off Disable import/no-unresolved
        \\  --import-no-self-import=off Disable import/no-self-import
        \\  --jsx-a11y-alt-text=off   Disable jsx-a11y/alt-text
        \\  --jsx-a11y-anchor-has-content=off Disable jsx-a11y/anchor-has-content
        \\  --jsx-a11y-aria-props=off Disable jsx-a11y/aria-props
        \\  --jsx-a11y-aria-proptypes=off Disable jsx-a11y/aria-proptypes
        \\  --jsx-a11y-aria-role=off Disable jsx-a11y/aria-role
        \\  --jsx-a11y-aria-unsupported-elements=off Disable jsx-a11y/aria-unsupported-elements
        \\  --jsx-a11y-iframe-has-title=off Disable jsx-a11y/iframe-has-title
        \\  --jsx-a11y-img-redundant-alt=off Disable jsx-a11y/img-redundant-alt
        \\  --jsx-a11y-no-access-key=off Disable jsx-a11y/no-access-key
        \\  --jsx-a11y-no-distracting-elements=off Disable jsx-a11y/no-distracting-elements
        \\  --jsx-a11y-role-has-required-aria-props=off Disable jsx-a11y/role-has-required-aria-props
        \\  --jsx-a11y-role-supports-aria-props=off Disable jsx-a11y/role-supports-aria-props
        \\  --jsx-a11y-scope=off      Disable jsx-a11y/scope
        \\  --no-invalid-regexp=off    Disable no-invalid-regexp
        \\  --no-irregular-whitespace=off Disable no-irregular-whitespace
        \\  --no-inline-comments=off   Disable no-inline-comments
        \\  --no-inner-declarations=off Disable no-inner-declarations
        \\  --no-iterator=off          Disable no-iterator
        \\  --no-label-var=off         Disable no-label-var
        \\  --no-labels=off           Disable no-labels
        \\  --no-lone-blocks=off      Disable no-lone-blocks
        \\  --no-lonely-if=off        Disable no-lonely-if
        \\  --no-loop-func=off        Disable no-loop-func
        \\  --no-loss-of-precision=off Disable no-loss-of-precision
        \\  --no-multi-str=off        Disable no-multi-str
        \\  --no-multi-assign=off     Disable no-multi-assign
        \\  --no-multi-spaces=off     Disable no-multi-spaces
        \\  --no-mixed-spaces-and-tabs=off Disable no-mixed-spaces-and-tabs
        \\  --no-misleading-character-class=off Disable no-misleading-character-class
        \\  --no-multiple-empty-lines=off Disable no-multiple-empty-lines
        \\  --no-nonoctal-decimal-escape=off Disable no-nonoctal-decimal-escape
        \\  --no-new=off              Disable no-new
        \\  --no-nested-ternary=off   Disable no-nested-ternary
        \\  --no-negated-condition=off Disable no-negated-condition
        \\  --no-new-native-nonconstructor=off Disable no-new-native-nonconstructor
        \\  --no-new-func=off         Disable no-new-func
        \\  --no-new-require=off      Disable no-new-require
        \\  --no-obj-calls=off        Disable no-obj-calls
        \\  --no-new-object=off       Disable no-new-object
        \\  --no-new-symbol=off       Disable no-new-symbol
        \\  --no-new-wrappers=off     Disable no-new-wrappers
        \\  --no-octal=off            Disable no-octal
        \\  --no-octal-escape=off     Disable no-octal-escape
        \\  --no-object-constructor=off Disable no-object-constructor
        \\  --no-param-reassign=off   Disable no-param-reassign
        \\  --no-path-concat=off      Disable no-path-concat
        \\  --no-plusplus=off         Disable no-plusplus
        \\  --no-promise-executor-return=off Disable no-promise-executor-return
        \\  --no-proto=off            Disable no-proto
        \\  --no-process-env=off      Disable no-process-env
        \\  --no-process-exit=off     Disable no-process-exit
        \\  --no-prototype-builtins=off Disable no-prototype-builtins
        \\  --no-redeclare=off        Disable no-redeclare
        \\  --no-regex-spaces=off     Disable no-regex-spaces
        \\  --no-return-await=off     Disable no-return-await
        \\  --no-return-assign=off    Disable no-return-assign
        \\  --no-useless-return=off   Disable no-useless-return
        \\  --no-script-url=off       Disable no-script-url
        \\  --no-self-assign=off      Disable no-self-assign
        \\  --no-self-compare=off     Disable no-self-compare
        \\  --no-setter-return=off    Disable no-setter-return
        \\  --no-shadow=off           Disable no-shadow
        \\  --no-shadow-restricted-names=off Disable no-shadow-restricted-names
        \\  --no-sequences=off        Disable no-sequences
        \\  --no-sparse-arrays=off    Disable no-sparse-arrays
        \\  --no-ternary=off          Disable no-ternary
        \\  --no-template-curly-in-string=off Disable no-template-curly-in-string
        \\  --no-throw-literal=off    Disable no-throw-literal
        \\  --no-this-before-super=off Disable no-this-before-super
        \\  --no-tabs=off             Disable no-tabs
        \\  --no-trailing-spaces=off  Disable no-trailing-spaces
        \\  --no-unreachable=off      Disable no-unreachable
        \\  --no-undef-init=off       Disable no-undef-init
        \\  --unicode-bom=off         Disable unicode-bom
        \\  --no-unneeded-ternary=off Disable no-unneeded-ternary
        \\  --no-unused-labels=off   Disable no-unused-labels
        \\  --no-unsafe-finally=off   Disable no-unsafe-finally
        \\  --no-unsafe-negation=off  Disable no-unsafe-negation
        \\  --no-useless-computed-key=off Disable no-useless-computed-key
        \\  --no-useless-call=off     Disable no-useless-call
        \\  --no-useless-concat=off   Disable no-useless-concat
        \\  --no-useless-constructor=off Disable no-useless-constructor
        \\  --no-useless-catch=off    Disable no-useless-catch
        \\  --no-useless-escape=off   Disable no-useless-escape
        \\  --no-useless-rename=off   Disable no-useless-rename
        \\  --no-unused-expressions=off Disable no-unused-expressions
        \\  --no-warning-comments=off Disable no-warning-comments
        \\  --no-void=off             Disable no-void
        \\  --no-with=off             Disable no-with
        \\  --no-var=off              Disable no-var
        \\  --one-var=off             Disable one-var
        \\  --object-shorthand=off    Disable object-shorthand
        \\  --operator-assignment=off Disable operator-assignment
        \\  --eqeqeq=off              Disable eqeqeq
        \\  --use-isnan=off           Disable use-isnan
        \\  --no-unused-vars=off      Disable no-unused-vars
        \\  --no-use-before-define=off Disable no-use-before-define
        \\  --no-undef=off            Disable no-undef
        \\  --prefer-const=off        Disable prefer-const
        \\  --prefer-exponentiation-operator=off Disable prefer-exponentiation-operator
        \\  --prefer-promise-reject-errors=off Disable prefer-promise-reject-errors
        \\  --prefer-destructuring=off Disable prefer-destructuring
        \\  --prefer-regex-literals=off Disable prefer-regex-literals
        \\  --prefer-rest-params=off  Disable prefer-rest-params
        \\  --prefer-spread=off       Disable prefer-spread
        \\  --prefer-template=off     Disable prefer-template
        \\  --react-default-props-match-prop-types=off Disable react/default-props-match-prop-types
        \\  --react-display-name=off Disable react/display-name
        \\  --react-jsx-boolean-value=off Disable react/jsx-boolean-value
        \\  --react-jsx-filename-extension=off Disable react/jsx-filename-extension
        \\  --react-jsx-no-duplicate-props=off Disable react/jsx-no-duplicate-props
        \\  --react-jsx-no-comment-textnodes=off Disable react/jsx-no-comment-textnodes
        \\  --react-jsx-no-bind=off Disable react/jsx-no-bind
        \\  --react-jsx-key=off Disable react/jsx-key
        \\  --react-button-has-type=off Disable react/button-has-type
        \\  --react-require-render-return=off Disable react/require-render-return
        \\  --react-jsx-no-target-blank=off Disable react/jsx-no-target-blank
        \\  --react-jsx-no-undef=off Disable react/jsx-no-undef
        \\  --react-jsx-pascal-case=off Disable react/jsx-pascal-case
        \\  --react-jsx-uses-react=off Disable react/jsx-uses-react
        \\  --react-jsx-uses-vars=off Disable react/jsx-uses-vars
        \\  --react-no-danger=off     Disable react/no-danger
        \\  --react-no-danger-with-children=off Disable react/no-danger-with-children
        \\  --react-no-access-state-in-setstate=off Disable react/no-access-state-in-setstate
        \\  --react-no-deprecated=off Disable react/no-deprecated
        \\  --react-forbid-prop-types=off Disable react/forbid-prop-types
        \\  --react-no-array-index-key=off Disable react/no-array-index-key
        \\  --react-no-children-prop=off Disable react/no-children-prop
        \\  --react-no-find-dom-node=off Disable react/no-find-dom-node
        \\  --react-no-is-mounted=off Disable react/no-is-mounted
        \\  --react-no-multi-comp=off Disable react/no-multi-comp
        \\  --react-no-redundant-should-component-update=off Disable react/no-redundant-should-component-update
        \\  --react-no-render-return-value=off Disable react/no-render-return-value
        \\  --react-no-will-update-set-state=off Disable react/no-will-update-set-state
        \\  --react-no-this-in-sfc=off Disable react/no-this-in-sfc
        \\  --react-no-typos=off Disable react/no-typos
        \\  --react-no-unknown-property=off Disable react/no-unknown-property
        \\  --react-prop-types=off Disable react/prop-types
        \\  --react-no-unused-prop-types=off Disable react/no-unused-prop-types
        \\  --react-no-unused-state=off Disable react/no-unused-state
        \\  --react-no-string-refs=off Disable react/no-string-refs
        \\  --react-no-unescaped-entities=off Disable react/no-unescaped-entities
        \\  --react-prefer-es6-class=off Disable react/prefer-es6-class
        \\  --react-self-closing-comp=off Disable react/self-closing-comp
        \\  --react-style-prop-object=off Disable react/style-prop-object
        \\  --react-void-dom-elements-no-children=off Disable react/void-dom-elements-no-children
        \\  --react-hooks-rules-of-hooks=off Disable react-hooks/rules-of-hooks
        \\  --radix=off               Disable radix
        \\  --require-atomic-updates=off Disable require-atomic-updates
        \\  --require-yield=off       Disable require-yield
        \\  --spaced-comment=off      Disable spaced-comment
        \\  --symbol-description=off  Disable symbol-description
        \\  --typescript-eslint-adjacent-overload-signatures=off Disable @typescript-eslint/adjacent-overload-signatures
        \\  --typescript-eslint-array-type=off Disable @typescript-eslint/array-type
        \\  --typescript-eslint-class-literal-property-style=off Disable @typescript-eslint/class-literal-property-style
        \\  --typescript-eslint-consistent-type-assertions=off Disable @typescript-eslint/consistent-type-assertions
        \\  --typescript-eslint-consistent-type-definitions=off Disable @typescript-eslint/consistent-type-definitions
        \\  --typescript-eslint-dot-notation=off Disable @typescript-eslint/dot-notation
        \\  --typescript-eslint-ban-ts-comment=off Disable @typescript-eslint/ban-ts-comment
        \\  --typescript-eslint-ban-tslint-comment=off Disable @typescript-eslint/ban-tslint-comment
        \\  --typescript-eslint-explicit-member-accessibility=off Disable @typescript-eslint/explicit-member-accessibility
        \\  --typescript-eslint-member-ordering=off Disable @typescript-eslint/member-ordering
        \\  --typescript-eslint-method-signature-style=off Disable @typescript-eslint/method-signature-style
        \\  --typescript-eslint-no-confusing-non-null-assertion=off Disable @typescript-eslint/no-confusing-non-null-assertion
        \\  --typescript-eslint-no-dupe-class-members=off Disable @typescript-eslint/no-dupe-class-members
        \\  --typescript-eslint-no-empty-interface=off Disable @typescript-eslint/no-empty-interface
        \\  --typescript-eslint-no-extra-non-null-assertion=off Disable @typescript-eslint/no-extra-non-null-assertion
        \\  --typescript-eslint-no-duplicate-enum-values=off Disable @typescript-eslint/no-duplicate-enum-values
        \\  --typescript-eslint-no-inferrable-types=off Disable @typescript-eslint/no-inferrable-types
        \\  --typescript-eslint-no-invalid-void-type=off Disable @typescript-eslint/no-invalid-void-type
        \\  --typescript-eslint-no-namespace=off Disable @typescript-eslint/no-namespace
        \\  --typescript-eslint-no-non-null-asserted-optional-chain=off Disable @typescript-eslint/no-non-null-asserted-optional-chain
        \\  --typescript-eslint-no-redeclare=off Disable @typescript-eslint/no-redeclare
        \\  --typescript-eslint-no-require-imports=off Disable @typescript-eslint/no-require-imports
        \\  --typescript-eslint-no-loop-func=off Disable @typescript-eslint/no-loop-func
        \\  --typescript-eslint-no-shadow=off Disable @typescript-eslint/no-shadow
        \\  --typescript-eslint-no-this-alias=off Disable @typescript-eslint/no-this-alias
        \\  --typescript-eslint-no-unsafe-declaration-merging=off Disable @typescript-eslint/no-unsafe-declaration-merging
        \\  --typescript-eslint-triple-slash-reference=off Disable @typescript-eslint/triple-slash-reference
        \\  --typescript-eslint-typedef=off Disable @typescript-eslint/typedef
        \\  --typescript-eslint-unified-signatures=off Disable @typescript-eslint/unified-signatures
        \\  --typescript-eslint-no-unnecessary-parameter-property-assignment=off Disable @typescript-eslint/no-unnecessary-parameter-property-assignment
        \\  --typescript-eslint-no-unnecessary-type-constraint=off Disable @typescript-eslint/no-unnecessary-type-constraint
        \\  --typescript-eslint-no-useless-empty-export=off Disable @typescript-eslint/no-useless-empty-export
        \\  --typescript-eslint-no-unused-expressions=off Disable @typescript-eslint/no-unused-expressions
        \\  --typescript-eslint-no-unused-vars=off Disable @typescript-eslint/no-unused-vars
        \\  --typescript-eslint-no-wrapper-object-types=off Disable @typescript-eslint/no-wrapper-object-types
        \\  --typescript-eslint-prefer-as-const=off Disable @typescript-eslint/prefer-as-const
        \\  --typescript-eslint-prefer-namespace-keyword=off Disable @typescript-eslint/prefer-namespace-keyword
        \\  --typescript-eslint-restrict-plus-operands=off Disable @typescript-eslint/restrict-plus-operands
        \\  --valid-typeof=off        Disable valid-typeof
        \\  --semantic-errors=off     Disable parser semantic errors
        \\  --yoda=off                Disable yoda
        \\
    , .{});
}
