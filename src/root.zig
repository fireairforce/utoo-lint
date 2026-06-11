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

    const needs_semantic = options.parser_semantic_errors or options.no_alert or options.no_global_is_finite or options.no_global_is_nan or options.no_unused_vars or options.no_undef;

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

fn countRule(result: Result, rule_id: []const u8) usize {
    var count: usize = 0;
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) count += 1;
    }
    return count;
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

test "reports no-alert for global alert APIs" {
    const source =
        \\alert("here");
        \\confirm("continue?");
        \\prompt("name");
        \\window.alert("hello");
        \\globalThis.prompt("name");
        \\window["confirm"]("continue?");
        \\(alert)("wrapped");
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), countRule(result, rules.no_alert.id));
}

test "does not report no-alert for shadowed alert" {
    const source =
        \\const alert = customAlert;
        \\alert("custom");
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_alert.id));
}

test "can disable no-alert" {
    const source =
        \\alert("here");
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_alert = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_alert.id));
}

test "reports no-global-is-nan for global isNaN calls" {
    const source =
        \\isNaN({});
        \\(isNaN)({});
        \\globalThis.isNaN({});
        \\globalThis["isNaN"]({});
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), countRule(result, rules.no_global_is_nan.id));
}

test "does not report no-global-is-nan for shadowed isNaN" {
    const source =
        \\function local(isNaN) {
        \\  isNaN({});
        \\}
        \\Number.isNaN({});
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_global_is_nan.id));
}

test "can disable no-global-is-nan" {
    const source =
        \\isNaN({});
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_global_is_nan = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_global_is_nan.id));
}

test "reports no-global-is-finite for global isFinite calls" {
    const source =
        \\isFinite({});
        \\(isFinite)({});
        \\globalThis.isFinite({});
        \\globalThis["isFinite"]({});
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), countRule(result, rules.no_global_is_finite.id));
}

test "does not report no-global-is-finite for shadowed isFinite" {
    const source =
        \\function local(isFinite) {
        \\  isFinite({});
        \\}
        \\Number.isFinite({});
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_global_is_finite.id));
}

test "can disable no-global-is-finite" {
    const source =
        \\isFinite({});
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_global_is_finite = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_global_is_finite.id));
}

test "reports no-comma-operator outside for init and update" {
    const source =
        \\const value = (doSomething(), 0);
        \\for (; doSomething(), test; ) {}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(hasRule(result, rules.no_comma_operator.id));
}

test "allows comma operator in for init and update" {
    const source =
        \\for (i = 0, j = 0; test; i++, j++) {}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_comma_operator.id));
}

test "can disable no-comma-operator" {
    const source =
        \\const value = (doSomething(), 0);
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_comma_operator = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_comma_operator.id));
}

test "reports no-proto for proto member access" {
    const source =
        \\obj.__proto__ = a;
        \\obj["__proto__"] = b;
        \\const c = obj.__proto__;
        \\const d = obj["__proto__"];
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(hasRule(result, rules.no_proto.id));
}

test "does not report no-proto for object literal proto property" {
    const source =
        \\const value = {
        \\  __proto__: null,
        \\  a: 1,
        \\};
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_proto.id));
}

test "can disable no-proto" {
    const source =
        \\const c = obj.__proto__;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_proto = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_proto.id));
}

test "reports no-void for void unary expressions" {
    const source =
        \\void 0;
        \\function f() {
        \\  return void 0;
        \\}
        \\const value = void(0);
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), countRule(result, rules.no_void.id));
}

test "does not report no-void for delete or property names" {
    const source =
        \\delete object.value;
        \\object.void();
        \\object.void = value;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_void.id));
}

test "can disable no-void" {
    const source =
        \\void 0;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_void = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_void.id));
}

test "reports no-unsafe-negation before in and instanceof" {
    const source =
        \\!value in object;
        \\!value instanceof Constructor;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), countRule(result, rules.no_unsafe_negation.id));
}

test "does not report no-unsafe-negation for other unary expressions" {
    const source =
        \\-value in object;
        \\~value in object;
        \\typeof value in object;
        \\void value in object;
        \\value instanceof Constructor;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_void = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_unsafe_negation.id));
}

test "can disable no-unsafe-negation" {
    const source =
        \\!value in object;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unsafe_negation = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_unsafe_negation.id));
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
