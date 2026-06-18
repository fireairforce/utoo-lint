const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "does not report no-inner-declarations for block-scoped function declarations by default" {
    const source =
        \\if (foo) {
        \\  function bar() {}
        \\}
        \\while (foo) {
        \\  function baz() {}
        \\}
        \\{
        \\  function qux() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_constant_condition = false,
        .no_lone_blocks = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_inner_declarations.id));
}

test "does not report no-inner-declarations for root function declarations" {
    const source =
        \\function topLevel() {}
        \\function outer() {
        \\  function inner() {}
        \\  const fn = function expression() {};
        \\}
        \\export function exported() {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_inner_declarations.id));
}

test "does not report no-inner-declarations for nested var declarations by default" {
    const source =
        \\if (foo) {
        \\  var nested = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .no_var = false,
        .parser_semantic_errors = false,
        .vars_on_top = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_inner_declarations.id));
}

test "reports no-inner-declarations for nested var declarations in both mode" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"both\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-inner-declarations", config.value);
    options.eol_last = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.no_var = false;
    options.parser_semantic_errors = false;
    options.vars_on_top = false;

    const source =
        \\var top = 1;
        \\function outer() {
        \\  var local = 1;
        \\  if (foo) {
        \\    var nested = 1;
        \\  }
        \\}
        \\class Example {
        \\  static {
        \\    var staticLocal = 1;
        \\  }
        \\}
        \\if (foo) {
        \\  var nestedTop = 1;
        \\}
        \\for (var index = 0; index < 1; index += 1) {}
        \\for (;;) {
        \\  var nestedLoop = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_inner_declarations.id));
    try std.testing.expectEqualStrings(
        "Move variable declaration to program or function body root.",
        result.diagnostics[0].message,
    );
}

test "can disable no-inner-declarations" {
    const source =
        \\if (foo) {
        \\  function bar() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_inner_declarations = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_inner_declarations.id));
}
