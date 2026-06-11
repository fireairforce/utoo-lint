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

pub const Options = struct {
    default_case: bool = true,
    default_case_last: bool = true,
    no_async_promise_executor: bool = true,
    no_array_constructor: bool = true,
    no_await_in_loop: bool = true,
    no_alert: bool = true,
    no_caller: bool = true,
    no_case_declarations: bool = true,
    no_class_assign: bool = true,
    no_cond_assign: bool = true,
    no_compare_neg_zero: bool = true,
    no_constant_condition: bool = true,
    no_const_assign: bool = true,
    no_control_regex: bool = true,
    no_console: bool = true,
    no_comma_operator: bool = true,
    no_constructor_return: bool = true,
    no_debugger: bool = true,
    no_dupe_else_if: bool = true,
    no_duplicate_case: bool = true,
    no_dupe_args: bool = true,
    no_dupe_keys: bool = true,
    no_delete_var: bool = true,
    no_div_regex: bool = true,
    no_empty_block_statements: bool = true,
    no_empty_character_class: bool = true,
    no_empty_function: bool = true,
    no_empty_pattern: bool = true,
    no_empty_static_block: bool = true,
    no_else_return: bool = true,
    no_eval: bool = true,
    no_ex_assign: bool = true,
    no_extra_semi: bool = true,
    no_extra_boolean_cast: bool = true,
    no_floating_decimal: bool = true,
    no_for_in: bool = true,
    no_func_assign: bool = true,
    no_global_is_finite: bool = true,
    no_global_is_nan: bool = true,
    no_implied_eval: bool = true,
    no_import_assign: bool = true,
    no_iterator: bool = true,
    no_labels: bool = true,
    no_lone_blocks: bool = true,
    no_lonely_if: bool = true,
    no_loss_of_precision: bool = true,
    no_multi_str: bool = true,
    no_new: bool = true,
    no_nested_ternary: bool = true,
    no_new_native_nonconstructor: bool = true,
    no_new_func: bool = true,
    no_obj_calls: bool = true,
    no_new_object: bool = true,
    no_new_symbol: bool = true,
    no_new_wrappers: bool = true,
    no_octal: bool = true,
    no_octal_escape: bool = true,
    no_plusplus: bool = true,
    no_promise_executor_return: bool = true,
    no_proto: bool = true,
    no_prototype_builtins: bool = true,
    no_regex_spaces: bool = true,
    no_return_await: bool = true,
    no_return_assign: bool = true,
    no_script_url: bool = true,
    no_self_assign: bool = true,
    no_self_compare: bool = true,
    no_setter_return: bool = true,
    no_sequences: bool = true,
    no_sparse_arrays: bool = true,
    no_ternary: bool = true,
    no_template_curly_in_string: bool = true,
    no_throw_literal: bool = true,
    no_unneeded_ternary: bool = true,
    no_unsafe_finally: bool = true,
    no_unsafe_negation: bool = true,
    no_useless_computed_key: bool = true,
    no_useless_call: bool = true,
    no_useless_concat: bool = true,
    no_useless_catch: bool = true,
    no_useless_rename: bool = true,
    no_void: bool = true,
    no_with: bool = true,
    no_var: bool = true,
    eqeqeq: bool = true,
    use_isnan: bool = true,
    no_unused_vars: bool = true,
    no_undef: bool = true,
    parser_semantic_errors: bool = true,
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
