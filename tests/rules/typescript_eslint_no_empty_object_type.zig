const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports empty object types and interfaces by default" {
    const source =
        \\interface Empty {}
        \\interface SingleExtends extends Base {}
        \\type EmptyAlias = {};
        \\let inlineValue: {};
        \\type EmptyUnion = {} | Base;
        \\interface MultiExtends extends Base, Other {}
        \\interface WithMember { value: string }
        \\type WithMemberAlias = { value: string };
        \\type Intersection = {} & Base;
        \\type ReverseIntersection = Base & {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.typescript_eslint_no_empty_object_type.id));
}

test "supports allowInterfaces and allowObjectTypes modes" {
    const source =
        \\interface Empty {}
        \\interface SingleExtends extends Base {}
        \\type EmptyAlias = {};
        \\let inlineValue: {};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowInterfaces\":\"with-single-extends\",\"allowObjectTypes\":\"always\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("@typescript-eslint/no-empty-object-type", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_empty_object_type.id));

    options.typescript_eslint_no_empty_object_type_allow_interfaces = .always;
    var allowed_result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer allowed_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(allowed_result, lint.rules.typescript_eslint_no_empty_object_type.id));
}

test "supports allowWithName for interfaces and direct object type aliases" {
    const source =
        \\interface InterfaceProps {}
        \\type TypeProps = {};
        \\interface InterfaceValue {}
        \\type TypeValue = {};
        \\let inlineValue: {};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowWithName\":\"Props$\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("@typescript-eslint/no-empty-object-type", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_no_empty_object_type.id));
}

test "does not duplicate deprecated no-empty-interface diagnostics" {
    var options = ruleOptions();
    options.typescript_eslint_no_empty_interface = true;

    var result = try lint.lintSource(std.testing.allocator, "interface Empty {}", "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_empty_object_type.id));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, lint.rules.typescript_eslint_no_empty_interface.id));
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.typescript_eslint_no_empty_object_type = true;
    return options;
}
