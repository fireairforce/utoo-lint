const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-this-alias for disallowed aliases" {
    const source =
        \\const that = this;
        \\let context;
        \\context = this;
        \\const wrapped = (this);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_no_this_alias.id));
}

test "does not report @typescript-eslint/no-this-alias for fishlint allowed self aliases or destructuring" {
    const source =
        \\const self = this;
        \\let self;
        \\self = this;
        \\const { props } = this;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_this_alias.id));
}

test "uses configured @typescript-eslint/no-this-alias allowedNames" {
    const source =
        \\const that = this;
        \\let context;
        \\context = this;
        \\const self = this;
    ;

    var allowed_names: @TypeOf((lint.Options{}).typescript_eslint_no_this_alias_allowed_names) = .{ .custom = true };
    try allowed_names.append("that");
    try allowed_names.append("context");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_this_alias_allowed_names = allowed_names,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_this_alias.id));
}

test "supports configured @typescript-eslint/no-this-alias allowedNames option" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        \\["error", {"allowedNames": ["that"], "allowDestructuring": false}]
    ,
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-this-alias", config.value);

    try std.testing.expect(options.typescript_eslint_no_this_alias);
    try std.testing.expect(options.typescript_eslint_no_this_alias_allowed_names.contains("that"));
    try std.testing.expect(!options.typescript_eslint_no_this_alias_allowed_names.contains("self"));
    try std.testing.expect(!options.typescript_eslint_no_this_alias_allow_destructuring);
}

test "supports configured @typescript-eslint/no-this-alias allowDestructuring false" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        \\["error", {"allowDestructuring": false}]
    ,
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("@typescript-eslint/no-this-alias", config.value);

    const source =
        \\const { props } = this;
        \\const [first] = this;
        \\let state;
        \\({ state } = this);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_no_this_alias.id));
}

test "can disable @typescript-eslint/no-this-alias" {
    const source =
        \\const that = this;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_this_alias = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_this_alias.id));
}
