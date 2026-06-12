const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-var-requires for require in disallowed expression contexts" {
    const source =
        \\const fs = require("fs");
        \\const joined = require("path").join;
        \\const typed = require("module") as unknown;
        \\const value = <unknown>require("value");
        \\const instance = new (require("factory"))();
        \\require("runner")();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_new = false,
        .no_new_require = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.typescript_eslint_no_var_requires.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_var_requires.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/no-var-requires for import statements or bare require calls" {
    const source =
        \\import fs = require("fs");
        \\require("side-effect");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_var_requires.id));
}

test "does not report @typescript-eslint/no-var-requires for local require functions" {
    const source =
        \\function require(name: string) {
        \\  return name;
        \\}
        \\const fs = require("fs");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_var_requires.id));
}

test "can disable @typescript-eslint/no-var-requires" {
    const source =
        \\const fs = require("fs");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_var_requires = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_var_requires.id));
}
