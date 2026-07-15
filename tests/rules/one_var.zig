const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports one-var for combined variable declarations" {
    const source =
        \\let first = 1, second = 2;
        \\const third = 3, fourth = 4;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.one_var.id));
}

test "autofixes combined variable declarations into separate statements" {
    const source =
        \\var first = 1, second = 2;
        \\let third = 3, fourth = 4;
        \\const fifth = 5, sixth = 6;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\var first = 1; var second = 2;
        \\let third = 3; let fourth = 4;
        \\const fifth = 5; const sixth = 6;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.one_var.id));
}

test "autofixes multiline declarations without discarding comments" {
    const source =
        \\var first = 1, // keep second
        \\    second = 2, /* keep third */ third = 3;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\var first = 1; // keep second
        \\    var second = 2; /* keep third */ var third = 3;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.one_var.id));
}

test "autofixes exported and ambient declarations with their modifiers" {
    const source =
        \\export const first = 1, second = 2;
        \\declare let third: number, fourth: string;
        \\export declare const fifth: number, sixth: string;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\export const first = 1; export const second = 2;
        \\declare let third: number; declare let fourth: string;
        \\export declare const fifth: number; export declare const sixth: string;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.one_var.id));
}

test "autofixes using and await using declarations" {
    const source =
        \\async function cleanup() {
        \\  using first = acquire(), second = acquire();
        \\  await using third = acquireAsync(), fourth = acquireAsync();
        \\}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\async function cleanup() {
        \\  using first = acquire(); using second = acquire();
        \\  await using third = acquireAsync(); await using fourth = acquireAsync();
        \\}
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.one_var.id));
}

test "does not autofix declarations outside statement lists" {
    const source =
        \\if (ready) var first = 1, second = 2;
        \\if (ready) { var third = 3, fourth = 4; }
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\if (ready) var first = 1, second = 2;
        \\if (ready) { var third = 3; var fourth = 4; }
    , result.output);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result.result, lint.rules.one_var.id));
}

test "autofixes destructuring declarations in switch cases without adding a final semicolon" {
    const source =
        \\switch (kind) {
        \\  case "value":
        \\    let { first } = source, [second] = values
        \\}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_case_declarations = false,
        .no_fallthrough = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\switch (kind) {
        \\  case "value":
        \\    let { first } = source; let [second] = values
        \\}
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.one_var.id));
}

test "does not report one-var for separate declarations or for loop init" {
    const source =
        \\let first = 1;
        \\let second = 2;
        \\for (let i = 0, j = 10; i < j; i++) {
        \\  second += i;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_plusplus = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.one_var.id));
}

test "supports configured one-var never style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("one-var", config.value);
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\var first = 1, second = 2;
        \\let third = 3, fourth = 4;
        \\const fifth = 5, sixth = 6;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.one_var.id));
}

test "supports configured one-var per-kind never style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"let\":\"never\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("one-var", config.value);
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\var first = 1, second = 2;
        \\let third = 3, fourth = 4;
        \\const fifth = 5, sixth = 6;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.one_var.id));
}

test "can disable one-var" {
    const source =
        \\let first = 1, second = 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .one_var = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.one_var.id));
}
