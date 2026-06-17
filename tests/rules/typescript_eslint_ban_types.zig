const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/ban-types for fishlint banned default types" {
    const source =
        \\let text: String;
        \\let flag: Boolean;
        \\let count: Number;
        \\let sym: Symbol;
        \\let big: BigInt;
        \\let fn: Function;
        \\let value: Object;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_wrapper_object_types = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.typescript_eslint_ban_types.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_ban_types.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/ban-types for fishlint allowed object forms" {
    const source =
        \\let value: object;
        \\let empty: {};
        \\let text: string;
        \\let count: number;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_ban_types.id));
}

test "supports @typescript-eslint/ban-types custom type config" {
    const source =
        \\let text: String;
        \\let value: object;
        \\let empty: {};
        \\let custom: CustomType;
    ;

    var config: @TypeOf((lint.Options{}).typescript_eslint_ban_types_config) = .{
        .extend_defaults = false,
    };
    try config.custom.append("object", "Use a named object shape.");
    try config.custom.append("{}", "Use Record<string, unknown>.");
    try config.custom.append("CustomType", "Use BetterType instead.");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_ban_types_config = config,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_ban_types.id));
    try std.testing.expect(hasMessage(result, "Don't use `object` as a type. Use a named object shape."));
    try std.testing.expect(hasMessage(result, "Don't use `{}` as a type. Use Record<string, unknown>."));
    try std.testing.expect(hasMessage(result, "Don't use `CustomType` as a type. Use BetterType instead."));
}

test "supports @typescript-eslint/ban-types disabled default types" {
    const source =
        \\let text: String;
        \\let count: Number;
    ;

    var config: @TypeOf((lint.Options{}).typescript_eslint_ban_types_config) = .{};
    try config.disabled.append("String");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_wrapper_object_types = false,
        .typescript_eslint_ban_types_config = config,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_ban_types.id));
    try std.testing.expect(hasMessage(result, "Don't use `Number` as a type. Use number instead"));
}

test "can disable @typescript-eslint/ban-types" {
    const source =
        \\let text: String;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_ban_types = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_ban_types.id));
}

fn hasMessage(result: lint.Result, expected: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, expected)) return true;
    }
    return false;
}
