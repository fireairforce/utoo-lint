const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports new-cap for lowercase constructors and uppercase function calls" {
    const source =
        \\new foo();
        \\new namespace.foo();
        \\Foo();
        \\namespace.Foo();
        \\namespace["Foo"]();
        \\new namespace[`foo`]();
        \\namespace[`Foo`]();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.new_cap.id));
}

test "does not report new-cap for conventional constructor usage callable builtins or dynamic members" {
    const source =
        \\new Foo();
        \\foo();
        \\new _foo();
        \\new $foo();
        \\_Foo();
        \\$Foo();
        \\new namespace.Foo();
        \\new namespace._foo();
        \\new namespace.$foo();
        \\namespace._Foo();
        \\namespace.$Foo();
        \\new namespace[`fo${suffix}`]();
        \\namespace[`Fo${suffix}`]();
        \\Array();
        \\Boolean();
        \\Date();
        \\Error();
        \\Number();
        \\Object();
        \\RegExp();
        \\String();
        \\Symbol();
        \\BigInt();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.new_cap.id));
}

test "can disable new-cap" {
    const source =
        \\new foo();
        \\Foo();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .new_cap = false,
        .no_new = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.new_cap.id));
}

test "supports configured new-cap newIsCap and capIsNew options" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"newIsCap\":false,\"capIsNew\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("new-cap", config.value);
    options.no_new = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\new foo();
        \\Foo();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.new_cap.id));
}

test "supports configured new-cap properties option" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"properties\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("new-cap", config.value);
    options.no_new = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\new foo();
        \\Foo();
        \\new namespace.foo();
        \\namespace.Foo();
        \\namespace["Foo"]();
        \\new namespace[`foo`]();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.new_cap.id));
}

test "supports configured new-cap exception name options" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"newIsCapExceptions\":[\"lowerFactory\"],\"capIsNewExceptions\":[\"UpperFactory\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("new-cap", config.value);
    options.no_new = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\new lowerFactory();
        \\new otherFactory();
        \\UpperFactory();
        \\OtherFactory();
        \\new namespace.lowerFactory();
        \\namespace.UpperFactory();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.new_cap.id));
}

test "supports configured new-cap exception pattern options" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"newIsCapExceptionPattern\":\"^lower.*Factory$\",\"capIsNewExceptionPattern\":\"^Upper.*Factory$\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("new-cap", config.value);
    options.no_new = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\new lowerWidgetFactory();
        \\new otherFactory();
        \\UpperWidgetFactory();
        \\OtherFactory();
        \\new namespace.lowerWidgetFactory();
        \\namespace.UpperWidgetFactory();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.new_cap.id));
}
