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

    var tree = try parser.parse(allocator, source, .{
        .source_type = ast.SourceType.fromPath(path),
        .lang = ast.Lang.fromPath(path),
    });
    defer tree.deinit();

    const needs_semantic = options.parser_semantic_errors or options.no_unused_vars or options.no_undef;

    if (needs_semantic) {
        var semantic_result = try parser.semantic.analyze(&tree);
        try semantic_result.symbol_table.resolveAll(semantic_result.scope_tree);
        try appendParserDiagnostics(allocator, &diagnostics, &tree);
        try rules.runBasic(allocator, &diagnostics, &tree, options);
        try rules.runSemantic(allocator, &diagnostics, &tree, semantic_result, options);
    } else {
        try appendParserDiagnostics(allocator, &diagnostics, &tree);
        try rules.runBasic(allocator, &diagnostics, &tree, options);
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

fn hasRule(result: Result, rule_id: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return true;
    }
    return false;
}

test "reports structural rules" {
    const source =
        \\var value = 1;
        \\if (value == 1) {
        \\  console.log(value);
        \\  debugger;
        \\}
        \\for (const key in value) {
        \\  console.log(key);
        \\}
        \\with (point) {
        \\  x = 1;
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.cjs", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(hasRule(result, rules.no_var.id));
    try std.testing.expect(hasRule(result, rules.eqeqeq.id));
    try std.testing.expect(hasRule(result, rules.no_console.id));
    try std.testing.expect(hasRule(result, rules.no_debugger.id));
    try std.testing.expect(hasRule(result, rules.no_for_in.id));
    try std.testing.expect(hasRule(result, rules.no_with.id));
}

test "can disable no-for-in" {
    const source =
        \\for (const key in object) {
        \\  console.log(key);
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_for_in = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_for_in.id));
}

test "can disable no-with" {
    const source =
        \\with (point) {
        \\  x = 1;
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.cjs", .{
        .no_with = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_with.id));
}

test "reports semantic rules" {
    const source =
        \\const unused = missing;
        \\const used = 1;
        \\console.log(used);
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.ts", .{});
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(hasRule(result, rules.no_unused_vars.id));
    try std.testing.expect(hasRule(result, rules.no_undef.id));
}
