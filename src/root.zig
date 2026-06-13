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
    var diagnostics: core.DiagnosticList = .empty;
    errdefer core.freeDiagnostics(allocator, &diagnostics);

    var effective_options = options;
    if (isDefinitionFile(path)) {
        effective_options.typescript_eslint_no_namespace = false;
    }

    var tree = try parser.parse(allocator, source, .{
        .source_type = ast.SourceType.fromPath(path),
        .lang = ast.Lang.fromPath(path),
    });
    defer tree.deinit();

    const needs_semantic = effective_options.parser_semantic_errors or effective_options.block_scoped_var or effective_options.no_array_constructor or effective_options.no_alert or effective_options.no_extra_boolean_cast or effective_options.no_global_is_finite or effective_options.no_global_is_nan or effective_options.no_invalid_regexp or effective_options.no_loop_func or effective_options.no_misleading_character_class or effective_options.no_new_func or effective_options.no_new_object or effective_options.no_new_symbol or effective_options.no_new_wrappers or effective_options.no_redeclare or effective_options.no_shadow or effective_options.no_unused_vars or effective_options.no_use_before_define or effective_options.no_undef or effective_options.prefer_const or effective_options.prefer_exponentiation_operator or effective_options.prefer_regex_literals or effective_options.radix or effective_options.require_atomic_updates or effective_options.symbol_description;

    if (needs_semantic) {
        var semantic_result = try parser.semantic.analyze(&tree);
        try semantic_result.symbol_table.resolveAll(semantic_result.scope_tree);
        try appendParserDiagnostics(allocator, &diagnostics, &tree);
        try rules.runBasic(allocator, &diagnostics, &tree, effective_options);
        try rules.runSemantic(allocator, &diagnostics, &tree, semantic_result, effective_options);
    } else {
        try appendParserDiagnostics(allocator, &diagnostics, &tree);
        try rules.runBasic(allocator, &diagnostics, &tree, effective_options);
    }

    return .{
        .diagnostics = try diagnostics.toOwnedSlice(allocator),
    };
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
