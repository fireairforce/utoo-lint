const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports script top-level var and function declarations" {
    const source =
        \\var badVar = 1;
        \\function badFn() {}
        \\let okLet = 2;
        \\const okConst = 3;
    ;

    var options = lint.Options.allDisabled();
    options.no_implicit_globals = true;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_implicit_globals.id));
    try std.testing.expectEqualStrings(
        "Implicit global variable declaration.",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqualStrings(
        "Implicit global function declaration.",
        result.diagnostics[1].message,
    );
}

test "reports lexical declarations when lexicalBindings is enabled" {
    const source =
        \\var badVar = 1;
        \\let badLet = 2;
        \\const badConst = 3;
        \\class BadClass {}
    ;

    var options = lint.Options.allDisabled();
    options.no_implicit_globals = true;
    options.no_implicit_globals_lexical_bindings = true;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_implicit_globals.id));
    try std.testing.expectEqualStrings(
        "Implicit global class declaration.",
        result.diagnostics[3].message,
    );
}

test "does not report modules or nested declarations" {
    const source =
        \\var moduleVar = 1;
        \\function moduleFn() {}
        \\if (moduleVar) {
        \\  var nested = 1;
        \\  function nestedFn() {}
        \\}
    ;

    var options = lint.Options.allDisabled();
    options.no_implicit_globals = true;
    options.no_implicit_globals_lexical_bindings = true;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    var module_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer module_result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(module_result, lint.rules.no_implicit_globals.id));

    const nested_source =
        \\if (flag) {
        \\  var nested = 1;
        \\  function nestedFn() {}
        \\  let blockLet = 2;
        \\}
    ;

    var script_result = try lint.lintSource(std.testing.allocator, nested_source, "fixture.cjs", options);
    defer script_result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(script_result, lint.rules.no_implicit_globals.id));
}

test "parses lexicalBindings config and can disable the rule" {
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\", {\"lexicalBindings\": true}]",
        .{},
    );
    defer parsed.deinit();

    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("no-implicit-globals", parsed.value);

    try std.testing.expect(options.no_implicit_globals);
    try std.testing.expect(options.no_implicit_globals_lexical_bindings);

    try options.setByRuleConfigValue("no-implicit-globals", .{ .string = "off" });
    try std.testing.expect(!options.no_implicit_globals);
}
