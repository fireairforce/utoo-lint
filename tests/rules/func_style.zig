const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const FuncStyle = @TypeOf(@as(lint.Options, .{}).func_style_style);

test "reports func-style expression mode for function declarations" {
    const source =
        \\function run() {}
        \\export default function defaultRun() {}
        \\const ok = function() {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options(.expression));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.func_style.id));
    try std.testing.expect(hasMessage(result, "Expected a function expression."));
}

test "reports func-style declaration mode for function expressions and arrows" {
    const source =
        \\const first = function() {};
        \\const second = () => 1;
        \\const third = () => this.value;
        \\function ok() {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options(.declaration));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.func_style.id));
    try std.testing.expect(hasMessage(result, "Expected a function declaration."));
}

test "honors func-style allowArrowFunctions" {
    const source =
        \\const first = function() {};
        \\const second = () => 1;
    ;

    var lint_options = options(.declaration);
    lint_options.func_style_allow_arrow_functions = true;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", lint_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.func_style.id));
}

test "honors func-style named export override" {
    const source =
        \\export function run() {}
        \\export const helper = function() {};
    ;

    var lint_options = options(.expression);
    lint_options.func_style_named_exports = .declaration;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", lint_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.func_style.id));
}

test "parses func-style config" {
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"declaration\",{\"allowArrowFunctions\":true,\"overrides\":{\"namedExports\":\"ignore\"}}]",
        .{},
    );
    defer parsed.deinit();

    var lint_options = baseOptions();
    try lint_options.setByRuleConfigValue("func-style", parsed.value);

    try std.testing.expect(lint_options.func_style);
    try std.testing.expectEqual(@as(FuncStyle, .declaration), lint_options.func_style_style);
    try std.testing.expect(lint_options.func_style_allow_arrow_functions);
    try std.testing.expectEqual(@as(@TypeOf(lint_options.func_style_named_exports), .ignore), lint_options.func_style_named_exports);
}

fn options(style: FuncStyle) lint.Options {
    var lint_options = baseOptions();
    lint_options.func_style = true;
    lint_options.func_style_style = style;
    return lint_options;
}

fn baseOptions() lint.Options {
    return .{
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.func_style.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
