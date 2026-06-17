const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/consistent-type-definitions for object type aliases" {
    const source =
        \\type User = {
        \\  name: string;
        \\};
        \\type Callable = {
        \\  (): void;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_consistent_type_definitions.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_consistent_type_definitions.id)) {
            try std.testing.expectEqual(lint.Severity.warning, diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/consistent-type-definitions for non-object aliases or interfaces" {
    const source =
        \\type Id = string | number;
        \\type Handler = () => void;
        \\interface User {
        \\  name: string;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_consistent_type_definitions.id));
}

test "reports @typescript-eslint/consistent-type-definitions for interfaces when configured type" {
    const source =
        \\interface User {
        \\  name: string;
        \\}
        \\interface Service<T> extends User {
        \\  get(value: T): string;
        \\}
        \\type ObjectAlias = {
        \\  value: string;
        \\};
        \\type Id = string | number;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_consistent_type_definitions_style = .type,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_consistent_type_definitions.id));
}

test "supports configured @typescript-eslint/consistent-type-definitions type style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        \\["error", "type"]
    ,
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    options.no_unused_vars = false;
    options.typescript_eslint_no_unused_vars = false;
    options.parser_semantic_errors = false;
    try options.setByRuleConfigValue("@typescript-eslint/consistent-type-definitions", config.value);

    const source =
        \\interface User {
        \\  name: string;
        \\}
        \\type ObjectAlias = {
        \\  value: string;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_consistent_type_definitions.id));
}

test "can disable @typescript-eslint/consistent-type-definitions" {
    const source =
        \\type User = {
        \\  name: string;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_consistent_type_definitions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_consistent_type_definitions.id));
}
