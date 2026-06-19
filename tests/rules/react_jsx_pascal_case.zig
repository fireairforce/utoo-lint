const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/jsx-pascal-case for non-pascal custom components" {
    const source =
        \\const first = <fooBar />;
        \\const second = <Foo.bar />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_pascal_case.id));
    try std.testing.expectEqualStrings("Imported JSX component bar must be in PascalCase or SCREAMING_SNAKE_CASE", result.diagnostics[0].message);
}

test "allows DOM tags pascal case and screaming snake case components" {
    const source =
        \\const dom = <div><span /></div>;
        \\const pascal = <FooBar><Foo.Bar /></FooBar>;
        \\const caps = <FOO_BAR><FOO.BAR /></FOO_BAR>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_pascal_case.id));
}

test "supports configured react/jsx-pascal-case allowAllCaps false" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowAllCaps\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("react/jsx-pascal-case", config.value);

    const source =
        \\const caps = <FOO_BAR><FOO.BAR /></FOO_BAR>;
        \\const pascal = <FooBar><Foo.Bar /></FooBar>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_jsx_pascal_case.id));
}

test "supports configured react/jsx-pascal-case ignore list" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignore\":[\"bar\",\"Legacy_widget\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("react/jsx-pascal-case", config.value);

    const source =
        \\const ignoredMember = <Foo.bar />;
        \\const ignoredRoot = <Legacy_widget />;
        \\const reported = <Foo.baz />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_pascal_case.id));
    try std.testing.expectEqualStrings("Imported JSX component baz must be in PascalCase or SCREAMING_SNAKE_CASE", result.diagnostics[0].message);
}

test "supports configured react/jsx-pascal-case allowLeadingUnderscore" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowLeadingUnderscore\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("react/jsx-pascal-case", config.value);

    const source =
        \\const allowedRoot = <_AllowedComponent />;
        \\const allowedMember = <Foo._Bar />;
        \\const reportedRoot = <_bad />;
        \\const reportedMember = <Foo._bad />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_jsx_pascal_case.id));
}

test "supports configured react/jsx-pascal-case allowNamespace" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowNamespace\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("react/jsx-pascal-case", config.value);

    const source =
        \\const allowedMember = <Foo.bar />;
        \\const allowedNestedMember = <Foo.bar.baz />;
        \\const reportedRoot = <Foo_bar.baz />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_pascal_case.id));
    try std.testing.expectEqualStrings("Imported JSX component Foo_bar must be in PascalCase or SCREAMING_SNAKE_CASE", result.diagnostics[0].message);
}

test "can disable react/jsx-pascal-case" {
    const source =
        \\const node = <Foo.bar />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .react_jsx_pascal_case = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_pascal_case.id));
}
