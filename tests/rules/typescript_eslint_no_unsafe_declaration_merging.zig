const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-unsafe-declaration-merging for class and interface with same name" {
    const source =
        \\class User {
        \\  name = "";
        \\}
        \\interface User {
        \\  id: string;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_inferrable_types = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_unsafe_declaration_merging.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_redeclare.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_unsafe_declaration_merging.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "allows safe declaration merging forms" {
    const source =
        \\interface User {
        \\  id: string;
        \\}
        \\interface User {
        \\  name: string;
        \\}
        \\class Store {}
        \\namespace Store {
        \\  export const version = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_empty_function = false,
        .typescript_eslint_no_inferrable_types = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unsafe_declaration_merging.id));
}

test "can disable @typescript-eslint/no-unsafe-declaration-merging" {
    const source =
        \\class User {}
        \\interface User {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_empty_function = false,
        .typescript_eslint_no_unsafe_declaration_merging = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unsafe_declaration_merging.id));
}

test "runs @typescript-eslint/no-unsafe-declaration-merging when it is the only enabled semantic rule" {
    const source =
        \\class User {}
        \\interface User {}
    ;

    var options = lint.Options.allDisabled();
    options.typescript_eslint_no_unsafe_declaration_merging = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_unsafe_declaration_merging.id));
}
