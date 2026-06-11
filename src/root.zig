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

    const needs_semantic = options.parser_semantic_errors or options.no_array_constructor or options.no_alert or options.no_extra_boolean_cast or options.no_global_is_finite or options.no_global_is_nan or options.no_new_func or options.no_new_object or options.no_new_symbol or options.no_new_wrappers or options.no_unused_vars or options.no_undef;

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

test "reports no-array-constructor for disallowed Array constructor usage" {
    const source =
        \\const a = Array();
        \\const b = new Array();
        \\const c = Array(1, 2);
        \\const d = new Array("a", "b");
        \\const e = Array(...items);
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), countRule(result, rules.no_array_constructor.id));
}

test "does not report no-array-constructor for single non-spread argument or shadowed Array" {
    const source =
        \\const a = Array(length);
        \\const b = new Array(10);
        \\function local(Array) {
        \\  const c = Array();
        \\  const d = new Array(1, 2);
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_array_constructor.id));
}

test "can disable no-array-constructor" {
    const source =
        \\const a = Array();
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_array_constructor = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_array_constructor.id));
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

test "reports no-cond-assign for unparenthesized assignments in conditions" {
    const source =
        \\if (value = next) { use(value); }
        \\while (node = node.parentNode) { use(node); }
        \\do { use(value); } while (value += 1);
        \\for (; value ||= next; ) { use(value); }
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), countRule(result, rules.no_cond_assign.id));
}

test "does not report no-cond-assign for parenthesized assignments or comparisons" {
    const source =
        \\if ((value = next)) { use(value); }
        \\while ((node = node.parentNode) !== null) { use(node); }
        \\do { use(value); } while ((value += 1));
        \\for (; value === next; ) { use(value); }
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_cond_assign.id));
}

test "can disable no-cond-assign" {
    const source =
        \\if (value = next) { use(value); }
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_cond_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_cond_assign.id));
}

test "reports no-constant-condition for constant boolean contexts" {
    const source =
        \\if ((true)) { use(); }
        \\while ("ready") { break; }
        \\do { break; } while (`ready`);
        \\for (; /ready/; ) { break; }
        \\const value = null ? 1 : 2;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), countRule(result, rules.no_constant_condition.id));
}

test "does not report no-constant-condition for dynamic conditions" {
    const source =
        \\if (ready) { use(); }
        \\while (`${ready}`) { break; }
        \\for (; ready; ) { break; }
        \\const value = ready ? 1 : 2;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_constant_condition.id));
}

test "can disable no-constant-condition" {
    const source =
        \\if (false) { use(); }
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_constant_condition.id));
}

test "reports no-control-regex for control characters in regex literals" {
    const source =
        \\const first = /\x1f/;
        \\const second = /\u001f/;
        \\const third = /\u{1f}/u;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), countRule(result, rules.no_control_regex.id));
}

test "does not report no-control-regex for printable regex escapes" {
    const source =
        \\const first = /\x20/;
        \\const second = /\u0020/;
        \\const third = /\cA/;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_control_regex.id));
}

test "can disable no-control-regex" {
    const source =
        \\const pattern = /\x1f/;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_control_regex = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_control_regex.id));
}

test "reports no-caller for arguments caller and callee access" {
    const source =
        \\function f() {
        \\  arguments.callee;
        \\  arguments.caller;
        \\  arguments["callee"];
        \\  arguments["caller"];
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), countRule(result, rules.no_caller.id));
}

test "does not report no-caller for other objects or properties" {
    const source =
        \\object.callee;
        \\arguments.length;
        \\arguments[name];
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_caller.id));
}

test "can disable no-caller" {
    const source =
        \\arguments.callee;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_caller = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_caller.id));
}

test "reports no-duplicate-case for repeated switch case labels" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    break;
        \\  case 2:
        \\    break;
        \\  case 1:
        \\    break;
        \\  case name:
        \\    break;
        \\  case name:
        \\    break;
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), countRule(result, rules.no_duplicate_case.id));
}

test "does not report no-duplicate-case for distinct labels or default clauses" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    break;
        \\  case "1":
        \\    break;
        \\  default:
        \\    break;
        \\}
        \\switch (other) {
        \\  case 1:
        \\    break;
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_duplicate_case.id));
}

test "can disable no-duplicate-case" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    break;
        \\  case 1:
        \\    break;
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_duplicate_case = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_duplicate_case.id));
}

test "reports no-dupe-keys for duplicate object literal keys" {
    const source =
        \\const object = {
        \\  alpha: 1,
        \\  alpha: 2,
        \\  "beta": 1,
        \\  beta: 2,
        \\};
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), countRule(result, rules.no_dupe_keys.id));
}

test "does not report no-dupe-keys for computed keys or getter setter pairs" {
    const source =
        \\const object = {
        \\  [alpha]: 1,
        \\  [alpha]: 2,
        \\  get value() { return 1; },
        \\  set value(next) {},
        \\};
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_dupe_keys.id));
}

test "can disable no-dupe-keys" {
    const source =
        \\const object = { alpha: 1, alpha: 2 };
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_dupe_keys = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_dupe_keys.id));
}

test "reports no-delete-var for deleting identifiers" {
    const source =
        \\delete value;
        \\delete undefined;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), countRule(result, rules.no_delete_var.id));
}

test "does not report no-delete-var for property deletion" {
    const source =
        \\delete object.value;
        \\delete object["value"];
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_delete_var.id));
}

test "can disable no-delete-var" {
    const source =
        \\delete value;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_delete_var = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_delete_var.id));
}

test "reports no-empty-block-statements for empty blocks" {
    const source =
        \\if (ready) {}
        \\function empty() {}
        \\class C {
        \\  static {}
        \\  method() {}
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), countRule(result, rules.no_empty_block_statements.id));
}

test "does not report no-empty-block-statements for commented blocks" {
    const source =
        \\if (ready) { /* intentionally empty */ }
        \\function empty() {
        \\  // intentionally empty
        \\}
        \\class C {
        \\  static { /* intentionally empty */ }
        \\  method() { /* intentionally empty */ }
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_empty_block_statements.id));
}

test "can disable no-empty-block-statements" {
    const source =
        \\if (ready) {}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_empty_block_statements.id));
}

test "reports no-extra-boolean-cast in boolean contexts" {
    const source =
        \\if (Boolean(value)) { use(value); }
        \\while (!!value) { break; }
        \\do { value++; } while (Boolean(value));
        \\for (; !!value; value++) { break; }
        \\const selected = Boolean(value) ? 1 : 2;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), countRule(result, rules.no_extra_boolean_cast.id));
}

test "does not report no-extra-boolean-cast outside boolean contexts or for shadowed Boolean" {
    const source =
        \\const a = Boolean(value);
        \\const b = !!value;
        \\function local(Boolean) {
        \\  if (Boolean(value)) { use(value); }
        \\}
        \\if (!value) { use(value); }
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_extra_boolean_cast.id));
}

test "can disable no-extra-boolean-cast" {
    const source =
        \\if (Boolean(value)) { use(value); }
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_extra_boolean_cast = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_extra_boolean_cast.id));
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

test "reports no-new-func for Function constructor usage" {
    const source =
        \\const a = new Function("return 1");
        \\const b = Function("return 1");
        \\const c = Function.call(null, "return 1");
        \\const d = Function.apply(null, ["return 1"]);
        \\const e = Function.bind(null, "return 1");
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), countRule(result, rules.no_new_func.id));
}

test "does not report no-new-func for shadowed Function" {
    const source =
        \\function local(Function) {
        \\  const a = new Function("return 1");
        \\  const b = Function("return 1");
        \\  const c = Function.call(null, "return 1");
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_new_func.id));
}

test "can disable no-new-func" {
    const source =
        \\const a = new Function("return 1");
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new_func = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_new_func.id));
}

test "reports no-new-object for constructed global Object" {
    const source =
        \\const value = new Object();
        \\const wrapped = new (Object)();
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), countRule(result, rules.no_new_object.id));
}

test "does not report no-new-object for calls or shadowed Object" {
    const source =
        \\const value = Object();
        \\function local(Object) {
        \\  const value = new Object();
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_new_object.id));
}

test "can disable no-new-object" {
    const source =
        \\const value = new Object();
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new_object = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_new_object.id));
}

test "reports no-new-symbol for constructed global Symbol" {
    const source =
        \\const foo = new Symbol("foo");
        \\const bar = new (Symbol)("bar");
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), countRule(result, rules.no_new_symbol.id));
}

test "does not report no-new-symbol for calls or shadowed Symbol" {
    const source =
        \\const foo = Symbol("foo");
        \\function local(Symbol) {
        \\  const bar = new Symbol("bar");
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_new_symbol.id));
}

test "can disable no-new-symbol" {
    const source =
        \\const foo = new Symbol("foo");
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new_symbol = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_new_symbol.id));
}

test "reports no-new-wrappers for global wrapper constructors" {
    const source =
        \\const string = new String("text");
        \\const number = new Number(1);
        \\const boolean = new Boolean(false);
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), countRule(result, rules.no_new_wrappers.id));
}

test "does not report no-new-wrappers for calls or shadowed constructors" {
    const source =
        \\const string = String(value);
        \\const number = Number(value);
        \\const boolean = Boolean(value);
        \\function local(String) {
        \\  const value = new String("text");
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_new_wrappers.id));
}

test "can disable no-new-wrappers" {
    const source =
        \\const string = new String("text");
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new_wrappers = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_new_wrappers.id));
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

test "reports no-empty-character-class for empty regex character classes" {
    const source =
        \\const first = /^abc[]/;
        \\const second = /foo[]bar/;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), countRule(result, rules.no_empty_character_class.id));
}

test "does not report no-empty-character-class for escaped or negated classes" {
    const source =
        \\const escaped = /\[\]/;
        \\const negated = /[^]/;
        \\const non_empty = /[a-z]/;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_empty_character_class.id));
}

test "can disable no-empty-character-class" {
    const source =
        \\const first = /^abc[]/;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_character_class = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_empty_character_class.id));
}

test "reports no-regex-spaces for consecutive regex pattern spaces" {
    const source =
        \\const first = /foo  bar/;
        \\const second = /foo   bar/;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), countRule(result, rules.no_regex_spaces.id));
}

test "does not report no-regex-spaces for escaped or character class spaces" {
    const source =
        \\const first = /foo bar/;
        \\const second = /foo\ \ bar/;
        \\const third = /[  ]/;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_regex_spaces.id));
}

test "can disable no-regex-spaces" {
    const source =
        \\const first = /foo  bar/;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_regex_spaces = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_regex_spaces.id));
}

test "reports no-sparse-arrays for array holes" {
    const source =
        \\const first = [1,, 2];
        \\const second = [,];
        \\const third = [,,];
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), countRule(result, rules.no_sparse_arrays.id));
}

test "does not report no-sparse-arrays for explicit values" {
    const source =
        \\const first = [1, undefined, 2];
        \\const second = [...items];
        \\const third = [];
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_sparse_arrays.id));
}

test "can disable no-sparse-arrays" {
    const source =
        \\const first = [1,, 2];
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_sparse_arrays = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_sparse_arrays.id));
}

test "reports no-self-compare for equivalent comparison operands" {
    const source =
        \\value === value;
        \\object.property != object.property;
        \\(count) < count;
        \\items[index] >= items[index];
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), countRule(result, rules.no_self_compare.id));
}

test "does not report no-self-compare for different operands or non-comparison operators" {
    const source =
        \\value === other;
        \\object.left === object.right;
        \\value + value;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_self_compare.id));
}

test "can disable no-self-compare" {
    const source =
        \\value === value;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_self_compare = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_self_compare.id));
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

test "reports no-compare-neg-zero for comparisons against negative zero" {
    const source =
        \\x === -0;
        \\-0 == x;
        \\x < -0;
        \\-0 >= x;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), countRule(result, rules.no_compare_neg_zero.id));
}

test "does not report no-compare-neg-zero for non-comparisons" {
    const source =
        \\x === 0;
        \\x === -1;
        \\x === +0;
        \\Object.is(x, -0);
        \\x || -0;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_compare_neg_zero.id));
}

test "can disable no-compare-neg-zero" {
    const source =
        \\x === -0;
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_compare_neg_zero = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!hasRule(result, rules.no_compare_neg_zero.id));
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
