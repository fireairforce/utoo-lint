const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-shadow for declarations in nested scopes" {
    const source =
        \\const a = 1;
        \\function f(a) {
        \\  let b = 1;
        \\  {
        \\    const b = 2;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_shadow.id));
}

test "does not report no-shadow for distinct sibling scopes or type declarations" {
    const source =
        \\function f() {
        \\  let a = 1;
        \\}
        \\function g() {
        \\  let a = 2;
        \\}
        \\interface Box {}
        \\function h() {
        \\  interface Box {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_shadow.id));
}

test "supports configured no-shadow allow names" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"done\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-shadow", config.value);
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\const done = 1;
        \\function f(done) {
        \\  return done;
        \\}
        \\const other = 1;
        \\function g(other) {
        \\  return other;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_shadow.id));
}

test "supports configured no-shadow built-in globals" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"builtinGlobals\":true,\"allow\":[\"Object\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-shadow", config.value);
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\function allowed(Object) {
        \\  return Object;
        \\}
        \\function reported(Array) {
        \\  return Array;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_shadow.id));
}

test "supports configured no-shadow hoist option" {
    const source =
        \\function defaultHoist() {
        \\  {
        \\    const laterValue = 1;
        \\    const laterFunction = 2;
        \\  }
        \\  const laterValue = 3;
        \\  function laterFunction() {}
        \\}
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer default_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.no_shadow.id));

    var all_options = lint.Options{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    var all_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"hoist\":\"all\"}]",
        .{},
    );
    defer all_config.deinit();
    try all_options.setByRuleConfigValue("no-shadow", all_config.value);

    var all_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", all_options);
    defer all_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(all_result, lint.rules.no_shadow.id));

    var never_options = lint.Options{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    var never_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"hoist\":\"never\"}]",
        .{},
    );
    defer never_config.deinit();
    try never_options.setByRuleConfigValue("no-shadow", never_config.value);

    var never_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", never_options);
    defer never_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(never_result, lint.rules.no_shadow.id));
}

test "can disable no-shadow" {
    const source =
        \\let a = 1;
        \\function f() {
        \\  let a = 2;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_shadow = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_shadow.id));
}
