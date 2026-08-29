const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports confusing multiline calls property access and tagged templates" {
    const source =
        \\const call = fn
        \\(value);
        \\const property = object
        \\[key];
        \\const template = tag
        \\`value`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_unexpected_multiline.id));
    try std.testing.expectEqualStrings("Unexpected newline between function and ( of function call.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Unexpected newline between object and [ of property access.", ruleDiagnostic(result, 1).message);
    try std.testing.expectEqualStrings("Unexpected newline between template tag and template literal.", ruleDiagnostic(result, 2).message);
}

test "reports regexp-looking multiline division" {
    const source =
        \\const value = numerator
        \\/ denominator /g.test(input);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unexpected_multiline.id));
    try std.testing.expectEqualStrings("Unexpected newline between numerator and division operator.", ruleDiagnostic(result, 0).message);
}

test "allows deliberate multiline expressions and optional chains" {
    const source =
        \\fn(
        \\  value
        \\);
        \\object[
        \\  key
        \\];
        \\tag `value`;
        \\const optionalCall = object?.
        \\  (value);
        \\const optionalProperty = object?.
        \\  [key];
        \\const division = numerator / denominator /g;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unexpected_multiline.id));
}

test "matches multiline division flag edge cases" {
    const source =
        \\const spacedFlags = numerator
        \\/ denominator / mgy;
        \\const flagsOnNextLine = numerator
        \\/ denominator /
        \\gym;
        \\const uppercaseFlags = numerator
        \\/ denominator /GYM;
        \\const ordinaryIdentifier = numerator
        \\/ denominator /value;
        \\const validFlags = numerator
        \\/ denominator /gimuy.test(input);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unexpected_multiline.id));
}

test "handles comments and TypeScript generic tagged templates" {
    const source =
        \\const call = fn /* a comment containing ( */
        \\(value);
        \\const valid = tag<
        \\  string
        \\>`value`;
        \\const invalid = tag<string>/*
        \\  comment
        \\*/`value`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unexpected_multiline.id));
}

test "uses the opening delimiter as the diagnostic span" {
    const source = "const value = fn\n  (argument);";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    const diagnostic = ruleDiagnostic(result, 0);
    try std.testing.expectEqual(@as(u32, 19), diagnostic.span.start);
    try std.testing.expectEqual(@as(u32, 20), diagnostic.span.end);
}

test "can disable no-unexpected-multiline" {
    const source = "const value = fn\n(argument);";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unexpected_multiline = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unexpected_multiline.id));
}

test "accepts ESLint-style no-unexpected-multiline configuration" {
    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "\"off\"", .{});
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-unexpected-multiline", config.value);
    try std.testing.expect(!options.no_unexpected_multiline);
}

fn ruleDiagnostic(result: lint.Result, wanted_index: usize) lint.Diagnostic {
    var found: usize = 0;
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_unexpected_multiline.id)) continue;
        if (found == wanted_index) return diagnostic;
        found += 1;
    }
    unreachable;
}
