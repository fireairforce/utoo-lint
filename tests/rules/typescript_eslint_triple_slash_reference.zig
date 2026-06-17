const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/triple-slash-reference for path references" {
    const source =
        \\/// <reference path="./foo.d.ts" />
        \\/// <reference path='./bar.d.ts' />
        \\export const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_triple_slash_reference.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_triple_slash_reference.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "allows @typescript-eslint/triple-slash-reference types and lib references" {
    const source =
        \\/// <reference types="node" />
        \\/// <reference lib="dom" />
        \\//// <reference path="./not-a-directive.d.ts" />
        \\export const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_triple_slash_reference.id));
}

test "allows @typescript-eslint/triple-slash-reference path references when configured always" {
    const source =
        \\/// <reference path="./foo.d.ts" />
        \\export const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_triple_slash_reference_path = .always,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_triple_slash_reference.id));
}

test "reports @typescript-eslint/triple-slash-reference types and lib references when configured never" {
    const source =
        \\/// <reference types="node" />
        \\/// <reference lib="dom" />
        \\export const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_triple_slash_reference_types = .never,
        .typescript_eslint_triple_slash_reference_lib = .never,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_triple_slash_reference.id));
}

test "supports configured @typescript-eslint/triple-slash-reference modes" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        \\["error", {"path": "always", "types": "never", "lib": "never"}]
    ,
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/triple-slash-reference", config.value);

    try std.testing.expect(options.typescript_eslint_triple_slash_reference);
    const Mode = @TypeOf((lint.Options{}).typescript_eslint_triple_slash_reference_path);
    try std.testing.expectEqual(Mode.always, options.typescript_eslint_triple_slash_reference_path);
    try std.testing.expectEqual(Mode.never, options.typescript_eslint_triple_slash_reference_types);
    try std.testing.expectEqual(Mode.never, options.typescript_eslint_triple_slash_reference_lib);
}

test "can disable @typescript-eslint/triple-slash-reference" {
    const source =
        \\/// <reference path="./foo.d.ts" />
        \\export const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_triple_slash_reference = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_triple_slash_reference.id));
}
