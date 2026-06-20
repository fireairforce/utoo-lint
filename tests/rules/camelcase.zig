const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports non-camelcase declarations and parameters" {
    const source =
        \\const bad_name = 1;
        \\const FOO_BAR = 2;
        \\function goodFn(bad_param, goodParam) {
        \\  return bad_param + goodParam;
        \\}
        \\class bad_class {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.camelcase.id));
    try std.testing.expect(hasMessage(result, "Identifier 'bad_name' is not in camel case."));
    try std.testing.expect(hasMessage(result, "Identifier 'bad_param' is not in camel case."));
    try std.testing.expect(hasMessage(result, "Identifier 'bad_class' is not in camel case."));
}

test "reports property names by default" {
    const source =
        \\class GoodClass {
        \\  #bad_private;
        \\  bad_field = 1;
        \\  bad_method() {}
        \\}
        \\const okName = { bad_key: 1, goodKey: 2, [computed_key]: 3 };
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.camelcase.id));
    try std.testing.expect(hasMessage(result, "Identifier '#bad_private' is not in camel case."));
    try std.testing.expect(hasMessage(result, "Identifier 'bad_field' is not in camel case."));
    try std.testing.expect(hasMessage(result, "Identifier 'bad_method' is not in camel case."));
    try std.testing.expect(hasMessage(result, "Identifier 'bad_key' is not in camel case."));
}

test "can ignore property names" {
    const source =
        \\class GoodClass {
        \\  bad_field = 1;
        \\  bad_method() {}
        \\}
        \\const okName = { bad_key: 1 };
    ;

    var options = baseOptions();
    options.camelcase_properties = .never;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.camelcase.id));
}

test "can ignore destructured bindings" {
    const source =
        \\const { bad_key: bad_local, bad_shorthand } = sourceObject;
        \\const [bad_item] = sourceList;
        \\const bad_name = 1;
    ;

    var options = baseOptions();
    options.camelcase_ignore_destructuring = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.camelcase.id));
    try std.testing.expect(hasMessage(result, "Identifier 'bad_name' is not in camel case."));
}

test "checks imports unless configured to ignore them" {
    const source =
        \\import bad_default, { snake_case, ok as bad_alias } from "pkg";
        \\import * as bad_namespace from "other";
        \\snake_case;
        \\bad_alias;
        \\bad_default;
        \\bad_namespace;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.camelcase.id));

    var options = baseOptions();
    options.camelcase_ignore_imports = true;
    var ignored = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer ignored.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(ignored, lint.rules.camelcase.id));
}

test "supports allow patterns" {
    const source =
        \\const legacy_name = 1;
        \\const bad_name = 2;
        \\const UNSAFE_VALUE = 3;
    ;

    var options = baseOptions();
    try options.camelcase_allow.append("legacy_name");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.camelcase.id));
    try std.testing.expect(hasMessage(result, "Identifier 'bad_name' is not in camel case."));
}

test "parses camelcase config" {
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"properties\":\"never\",\"ignoreDestructuring\":true,\"ignoreImports\":true,\"ignoreGlobals\":true,\"allow\":[\"legacy_name\",\"^UNSAFE_\"]}]",
        .{},
    );
    defer parsed.deinit();

    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("camelcase", parsed.value);

    try std.testing.expect(options.camelcase);
    try std.testing.expectEqual(@as(@TypeOf(options.camelcase_properties), .never), options.camelcase_properties);
    try std.testing.expect(options.camelcase_ignore_destructuring);
    try std.testing.expect(options.camelcase_ignore_imports);
    try std.testing.expect(options.camelcase_ignore_globals);
    try std.testing.expect(options.camelcase_allow.matches("legacy_name"));
    try std.testing.expect(options.camelcase_allow.matches("UNSAFE_value"));
}

test "can disable camelcase" {
    const source =
        \\const bad_name = 1;
    ;

    var options = baseOptions();
    options.camelcase = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.camelcase.id));
}

fn baseOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.camelcase = true;
    options.camelcase_properties = .always;
    return options;
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.camelcase.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
