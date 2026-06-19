const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports uninitialized declarations in always mode" {
    const source =
        \\let missing;
        \\let present = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.init_declarations.id));
    try std.testing.expect(hasMessage(result, "Variable 'missing' should be initialized on declaration."));
}

test "treats for loop variable declarations as initialized in always mode" {
    const source =
        \\const obj = {};
        \\const items = [];
        \\for (let i; i < 1; i++) {}
        \\for (let key in obj) {}
        \\for (let item of items) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.init_declarations.id));
}

test "reports initialized non-const declarations in never mode" {
    const source =
        \\let value = 1;
        \\var other = 2;
        \\const fixed = 3;
        \\let missing;
    ;

    var options = baseOptions();
    options.init_declarations_mode = .never;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.init_declarations.id));
    try std.testing.expect(hasMessage(result, "Variable 'value' should not be initialized on declaration."));
}

test "supports ignoreForLoopInit in never mode" {
    const source =
        \\for (let i = 0; i < 1; i++) {}
        \\let value = 1;
    ;

    var options = baseOptions();
    options.init_declarations_mode = .never;
    options.init_declarations_ignore_for_loop_init = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.init_declarations.id));
    try std.testing.expect(hasMessage(result, "Variable 'value' should not be initialized on declaration."));
}

test "parses eslint init-declarations config" {
    const source =
        \\for (let i = 0; i < 1; i++) {}
        \\let value = 1;
    ;

    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"ignoreForLoopInit\":true}]",
        .{},
    );
    defer parsed.deinit();
    try options.setByRuleConfigValue("init-declarations", parsed.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.init_declarations.id));
    try std.testing.expect(hasMessage(result, "Variable 'value' should not be initialized on declaration."));
}

test "skips declare variable declarations and declared namespaces" {
    const source =
        \\declare var declared: string;
        \\declare namespace Foo {
        \\  let nested: string;
        \\}
        \\let outside: string;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.init_declarations.id));
    try std.testing.expect(hasMessage(result, "Variable 'outside' should be initialized on declaration."));
}

test "can disable init-declarations" {
    const source =
        \\let missing;
    ;

    var options = baseOptions();
    options.init_declarations = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.init_declarations.id));
}

fn baseOptions() lint.Options {
    return .{
        .init_declarations = true,
        .max_statements = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.init_declarations.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
