const std = @import("std");
const parser = @import("parser");
const core = @import("core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const Severity = core.Severity;
pub const Options = core.Options;
pub const Diagnostic = core.Diagnostic;
pub const Result = core.Result;
pub const SourcePosition = core.SourcePosition;
pub const rules = @import("rules/root.zig");

pub fn lintSource(
    allocator: Allocator,
    source: []const u8,
    path: []const u8,
    options: Options,
) Allocator.Error!Result {
    return lintSourceWithIo(allocator, null, source, path, options);
}

pub fn lintSourceWithIo(
    allocator: Allocator,
    io: ?std.Io,
    source: []const u8,
    path: []const u8,
    options: Options,
) Allocator.Error!Result {
    var diagnostics: core.DiagnosticList = .empty;
    errdefer core.freeDiagnostics(allocator, &diagnostics);

    var effective_options = options;
    if (isDefinitionFile(path)) {
        effective_options.typescript_eslint_no_namespace = false;
    }

    var tree = try parseSource(allocator, source, path);
    defer tree.deinit();

    const needs_semantic = hasSemanticRules(effective_options);

    if (needs_semantic) {
        var semantic_result = try parser.semantic.analyze(&tree);
        try semantic_result.symbol_table.resolveAll(semantic_result.scope_tree);
        try appendParserDiagnostics(allocator, &diagnostics, &tree);
        try rules.runBasic(allocator, &diagnostics, &tree, path, effective_options);
        try rules.runSemantic(allocator, &diagnostics, &tree, io, path, semantic_result, effective_options);
    } else {
        try appendParserDiagnostics(allocator, &diagnostics, &tree);
        try rules.runBasic(allocator, &diagnostics, &tree, path, effective_options);
    }

    return .{
        .diagnostics = try diagnostics.toOwnedSlice(allocator),
    };
}

fn parseSource(allocator: Allocator, source: []const u8, path: []const u8) Allocator.Error!ast.Tree {
    var tree = try parser.parse(allocator, source, .{
        .source_type = ast.SourceType.fromPath(path),
        .lang = ast.Lang.fromPath(path),
    });

    const fallback_lang = jsxFallbackLang(path) orelse return tree;
    if (!tree.hasErrors()) return tree;

    var fallback_tree = try parser.parse(allocator, source, .{
        .source_type = ast.SourceType.fromPath(path),
        .lang = fallback_lang,
    });
    if (fallback_tree.hasErrors()) {
        fallback_tree.deinit();
        return tree;
    }

    tree.deinit();
    return fallback_tree;
}

fn jsxFallbackLang(path: []const u8) ?ast.Lang {
    if (std.mem.endsWith(u8, path, ".js") or
        std.mem.endsWith(u8, path, ".mjs") or
        std.mem.endsWith(u8, path, ".cjs"))
    {
        return .jsx;
    }

    if (std.mem.endsWith(u8, path, ".ts") or
        std.mem.endsWith(u8, path, ".mts") or
        std.mem.endsWith(u8, path, ".cts"))
    {
        return .tsx;
    }

    return null;
}

pub fn isLintablePath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".js") or
        std.mem.endsWith(u8, path, ".jsx") or
        std.mem.endsWith(u8, path, ".ts") or
        std.mem.endsWith(u8, path, ".tsx") or
        std.mem.endsWith(u8, path, ".mjs") or
        std.mem.endsWith(u8, path, ".cjs") or
        std.mem.endsWith(u8, path, ".mts") or
        std.mem.endsWith(u8, path, ".cts");
}

fn isDefinitionFile(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".d.ts") or
        std.mem.endsWith(u8, path, ".d.mts") or
        std.mem.endsWith(u8, path, ".d.cts");
}

fn hasSemanticRules(options: Options) bool {
    return options.parser_semantic_errors or
        options.block_scoped_var or
        options.no_array_constructor or
        options.no_alert or
        options.no_async_promise_executor or
        options.no_buffer_constructor or
        options.no_class_assign or
        options.no_const_assign or
        options.no_eval or
        options.no_ex_assign or
        options.no_extend_native or
        options.no_extra_boolean_cast or
        options.no_func_assign or
        options.no_global_assign or
        options.no_global_is_finite or
        options.no_global_is_nan or
        options.no_implied_eval or
        options.no_import_assign or
        options.alipay_ant_no_phantom_dependencies or
        options.import_default or
        options.import_export or
        options.import_named or
        options.import_no_named_as_default or
        options.import_no_named_as_default_member or
        options.no_invalid_regexp or
        options.no_label_var or
        options.no_loop_func or
        options.no_misleading_character_class or
        options.no_new_func or
        options.no_new_native_nonconstructor or
        options.no_new_object or
        options.no_new_symbol or
        options.no_new_wrappers or
        options.no_obj_calls or
        options.no_object_constructor or
        options.no_promise_executor_return or
        options.no_redeclare or
        options.no_shadow or
        options.no_undef or
        options.react_jsx_no_undef or
        options.no_unused_vars or
        options.no_use_before_define or
        options.prefer_const or
        options.prefer_exponentiation_operator or
        options.prefer_promise_reject_errors or
        options.prefer_regex_literals or
        options.radix or
        options.require_atomic_updates or
        options.symbol_description or
        options.typescript_eslint_no_redeclare or
        options.typescript_eslint_no_require_imports or
        options.typescript_eslint_no_loop_func or
        options.typescript_eslint_no_shadow or
        options.typescript_eslint_no_unsafe_declaration_merging or
        options.typescript_eslint_no_unused_vars or
        options.typescript_eslint_no_use_before_define or
        options.typescript_eslint_no_var_requires;
}

pub fn offsetToLineColumn(source: []const u8, offset: u32) SourcePosition {
    const offset_usize: usize = @intCast(offset);
    const end = @min(offset_usize, source.len);
    var line: usize = 1;
    var column: usize = 1;
    var index: usize = 0;

    while (index < end) : (index += 1) {
        if (source[index] == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }
    }

    return .{ .line = line, .column = column };
}

fn appendParserDiagnostics(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    for (tree.diagnostics.items) |diagnostic| {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            if (diagnostic.severity == .@"error") .@"error" else .warning,
            "parse",
            diagnostic.message,
            diagnostic.span,
        );
    }
}
