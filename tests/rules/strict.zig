const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const StrictMode = @TypeOf(@as(lint.Options, .{}).strict_mode);

test "reports strict global mode when program directive is missing" {
    const source =
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options(.global));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.strict.id));
    try std.testing.expect(hasMessage(result, "Use the global form of 'use strict'."));
}

test "reports strict duplicate global directives" {
    const source =
        \\"use strict";
        \\"use strict";
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options(.global));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.strict.id));
    try std.testing.expect(hasMessage(result, "Multiple 'use strict' directives."));
}

test "autofixes duplicate global directives" {
    const source = "\"use strict\"; \"use strict\"; const value = 1;";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.cjs", options(.global));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("\"use strict\";  const value = 1;", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.strict.id));
}

test "reports strict function mode for top-level functions without directives" {
    const source =
        \\function run(value) {
        \\  return value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options(.function));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.strict.id));
    try std.testing.expect(hasMessage(result, "Use the function form of 'use strict'."));
}

test "allows strict function mode for function directives" {
    const source =
        \\function run(value) {
        \\  "use strict";
        \\  return value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options(.function));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.strict.id));
}

test "autofixes directives inherited from a strict parent function" {
    const source = "function outer() { \"use strict\"; return function inner() { \"use strict\"; return 1; }; }";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.cjs", options(.function));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        "function outer() { \"use strict\"; return function inner() {  return 1; }; }",
        result.output,
    );
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.strict.id));
}

test "autofixes directives inside classes" {
    const source = "class Example { method() { \"use strict\"; return 1; } }";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.cjs", options(.function));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("class Example { method() {  return 1; } }", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.strict.id));
}

test "reports strict never mode and module directives" {
    const source =
        \\"use strict";
        \\const value = 1;
    ;

    var never_result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options(.never));
    defer never_result.deinit(std.testing.allocator);
    try std.testing.expect(hasMessage(never_result, "Strict mode is not permitted."));

    var module_result = try lint.lintSource(std.testing.allocator, source, "fixture.mjs", options(.safe));
    defer module_result.deinit(std.testing.allocator);
    try std.testing.expect(hasMessage(module_result, "'use strict' is unnecessary inside of modules."));
}

test "autofixes unnecessary module directives" {
    const source = "\"use strict\"; export function run() { \"use strict\"; return 1; }";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.mjs", options(.safe));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(" export function run() {  return 1; }", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.strict.id));
}

test "autofix preserves comments around removed directives" {
    const source = "/* before */ \"use strict\"; /* after */ export const value = 1;";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.mjs", options(.safe));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("/* before */  /* after */ export const value = 1;", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.strict.id));
}

test "does not autofix diagnostics that could change strict-mode semantics" {
    const Case = struct {
        source: []const u8,
        mode: StrictMode,
    };
    const cases = [_]Case{
        .{ .source = "\"use strict\"; call();", .mode = .never },
        .{ .source = "call();", .mode = .global },
        .{ .source = "function run() {}", .mode = .function },
        .{ .source = "function run(value = 1) { \"use strict\"; return value; }", .mode = .function },
    };

    for (cases) |case| {
        var result = try lint.lintSourceAndFix(std.testing.allocator, case.source, "fixture.cjs", options(case.mode));
        defer result.deinit(std.testing.allocator);

        try std.testing.expect(!result.fixed);
        try std.testing.expectEqualStrings(case.source, result.output);
        try std.testing.expect(helpers.hasRule(result.result, lint.rules.strict.id));
        for (result.result.diagnostics) |diagnostic| {
            if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.strict.id)) {
                try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
            }
        }
    }
}

test "autofixes only duplicate directives with non-simple parameters" {
    const source = "function run(value = 1) { \"use strict\"; \"use strict\"; return value; }";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.cjs", options(.function));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        "function run(value = 1) { \"use strict\";  return value; }",
        result.output,
    );
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result.result, lint.rules.strict.id));
    try std.testing.expect(hasMessage(result.result, "non-simple parameter list"));
    try std.testing.expectEqual(@as(usize, 0), result.result.diagnostics[0].fixes.len);
}

test "parses strict config mode" {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "[\"error\",\"never\"]", .{});
    defer parsed.deinit();

    var lint_options = baseOptions();
    try lint_options.setByRuleConfigValue("strict", parsed.value);

    try std.testing.expect(lint_options.strict);
    try std.testing.expectEqual(@as(StrictMode, .never), lint_options.strict_mode);
}

fn options(mode: StrictMode) lint.Options {
    var lint_options = baseOptions();
    lint_options.strict = true;
    lint_options.strict_mode = mode;
    return lint_options;
}

fn baseOptions() lint.Options {
    return .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_multi_spaces = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.strict.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
