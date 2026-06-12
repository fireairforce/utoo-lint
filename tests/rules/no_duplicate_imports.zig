const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-duplicate-imports for repeated module sources" {
    const source =
        \\import foo from "alpha";
        \\import { bar } from "alpha";
        \\import "beta";
        \\import "beta";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_duplicate_imports.id));
    try std.testing.expectEqualStrings("Duplicate import from \"alpha\".", result.diagnostics[0].message);
}

test "does not report no-duplicate-imports for distinct module sources" {
    const source =
        \\import foo from "alpha";
        \\import { bar } from "beta";
        \\import "gamma";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_duplicate_imports.id));
}

test "can disable no-duplicate-imports" {
    const source =
        \\import foo from "alpha";
        \\import { bar } from "alpha";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_duplicate_imports = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_duplicate_imports.id));
}
