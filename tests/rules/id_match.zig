const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports declaration identifiers that do not match the pattern" {
    const source =
        \\const okValue = 1;
        \\const badValue = 2;
        \\function okFn(okParam, badParam) {
        \\  return okParam + badParam;
        \\}
        \\class badClass {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.id_match.id));
    try std.testing.expect(hasMessage(result, "Identifier 'badValue' does not match the pattern '^ok'."));
    try std.testing.expect(hasMessage(result, "Identifier 'badParam' does not match the pattern '^ok'."));
    try std.testing.expect(hasMessage(result, "Identifier 'badClass' does not match the pattern '^ok'."));
}

test "reports import aliases but skips unrenamed named imports" {
    const source =
        \\import badDefault, { value as badAlias, okNamed } from "pkg";
        \\import * as badNamespace from "other";
        \\okNamed;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.id_match.id));
    try std.testing.expect(hasMessage(result, "Identifier 'badDefault' does not match the pattern '^ok'."));
    try std.testing.expect(hasMessage(result, "Identifier 'badAlias' does not match the pattern '^ok'."));
    try std.testing.expect(hasMessage(result, "Identifier 'badNamespace' does not match the pattern '^ok'."));
}

test "checks properties and class fields when configured" {
    const source =
        \\class okClass {
        \\  #badPrivate;
        \\  badField = 1;
        \\  badMethod() {}
        \\  okMethod() {}
        \\}
        \\const okValue = { badKey: 1, okKey: 2, [computed]: 3 };
    ;

    var options = baseOptions();
    options.id_match_properties = true;
    options.id_match_class_fields = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.id_match.id));
    try std.testing.expect(hasMessage(result, "Identifier '#badPrivate' does not match the pattern '^ok'."));
    try std.testing.expect(hasMessage(result, "Identifier 'badField' does not match the pattern '^ok'."));
    try std.testing.expect(hasMessage(result, "Identifier 'badMethod' does not match the pattern '^ok'."));
    try std.testing.expect(hasMessage(result, "Identifier 'badKey' does not match the pattern '^ok'."));
}

test "ignores properties and class fields by default" {
    const source =
        \\class okClass {
        \\  badField = 1;
        \\  badMethod() {}
        \\}
        \\const okValue = { badKey: 1 };
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.id_match.id));
}

test "can ignore destructured bindings" {
    const source =
        \\const { badKey: badLocal, okKey } = sourceObject;
        \\const [badItem] = sourceList;
        \\const badValue = 1;
    ;

    var options = baseOptions();
    options.id_match_ignore_destructuring = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.id_match.id));
    try std.testing.expect(hasMessage(result, "Identifier 'badValue' does not match the pattern '^ok'."));
}

test "parses eslint id-match config" {
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"^ok\",{\"properties\":true,\"classFields\":true,\"onlyDeclarations\":true,\"ignoreDestructuring\":true}]",
        .{},
    );
    defer parsed.deinit();

    var options = baseOptions();
    try options.setByRuleConfigValue("id-match", parsed.value);

    try std.testing.expect(options.id_match);
    try std.testing.expect(options.id_match_pattern.matches("okName"));
    try std.testing.expect(!options.id_match_pattern.matches("badName"));
    try std.testing.expect(options.id_match_properties);
    try std.testing.expect(options.id_match_class_fields);
    try std.testing.expect(options.id_match_only_declarations);
    try std.testing.expect(options.id_match_ignore_destructuring);
}

test "can disable id-match" {
    const source =
        \\const badValue = 1;
    ;

    var options = baseOptions();
    options.id_match = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.id_match.id));
}

fn baseOptions() lint.Options {
    var options = lint.Options{
        .consistent_return = false,
        .import_no_unresolved = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unassigned_vars = false,
        .no_unused_private_class_members = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_empty_function = false,
    };
    options.id_match = true;
    options.id_match_pattern.set("^ok") catch unreachable;
    return options;
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.id_match.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
