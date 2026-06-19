const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-restricted-properties for configured object properties" {
    const source =
        \\disallowedObject.disallowedProperty;
        \\disallowedObject.disallowedProperty();
        \\disallowedObject["disallowedProperty"];
        \\allowedObject.disallowedProperty;
    ;

    const options = try optionsWithConfig(
        "[\"error\",{\"object\":\"disallowedObject\",\"property\":\"disallowedProperty\",\"message\":\"Use allowedObject.allowedProperty.\"}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_restricted_properties.id));
    try std.testing.expect(hasMessage(result, "Use allowedObject.allowedProperty."));
}

test "reports no-restricted-properties for global properties and destructuring" {
    const source =
        \\foo.__defineGetter__(bar, baz);
        \\const { __defineGetter__ } = qux();
        \\({ __defineGetter__ }) => {};
    ;

    const options = try optionsWithConfig("[\"error\",{\"property\":\"__defineGetter__\"}]");
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_restricted_properties.id));
}

test "reports no-restricted-properties for any property on an object" {
    const source =
        \\require.resolve("foo");
        \\require.cache;
        \\require("foo");
        \\other.resolve("foo");
    ;

    const options = try optionsWithConfig("[\"error\",{\"object\":\"require\"}]");
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_restricted_properties.id));
}

test "honors no-restricted-properties allowObjects and allowProperties" {
    const source =
        \\myArray.push(5);
        \\router.push(5);
        \\config.apiKey = "12345";
        \\config.settings = {};
        \\config.version = "1.0.0";
    ;

    const options = try optionsWithConfig(
        "[\"error\",{\"property\":\"push\",\"allowObjects\":[\"router\"]},{\"object\":\"config\",\"allowProperties\":[\"settings\",\"version\"]}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_restricted_properties.id));
}

test "allows no-restricted-properties for unrelated access and dynamic names" {
    const source =
        \\allowedObject.disallowedProperty;
        \\disallowedObject.allowedProperty;
        \\disallowedObject[dynamicName];
        \\const { allowedProperty } = qux();
    ;

    const options = try optionsWithConfig("[\"error\",{\"object\":\"disallowedObject\",\"property\":\"disallowedProperty\"}]");
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_restricted_properties.id));
}

test "can disable no-restricted-properties" {
    const source =
        \\disallowedObject.disallowedProperty;
    ;

    var options = try optionsWithConfig("[\"error\",{\"object\":\"disallowedObject\",\"property\":\"disallowedProperty\"}]");
    options.no_restricted_properties = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_restricted_properties.id));
}

fn optionsWithConfig(config: []const u8) !lint.Options {
    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue("no-restricted-properties", parsed.value);
    return options;
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
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_restricted_properties.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
