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
        .import_no_duplicates = false,
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
        .import_no_duplicates = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_duplicate_imports.id));
}

test "does not report no-duplicate-imports for namespace and named imports" {
    const source =
        \\import * as alpha from "alpha";
        \\import { bar } from "alpha";
        \\import { baz } from "beta";
        \\import * as beta from "beta";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .import_no_duplicates = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_duplicate_imports.id));
}

test "reports no-duplicate-imports for namespace imports that can be merged" {
    const source =
        \\import * as alpha from "alpha";
        \\import defaultAlpha from "alpha";
        \\import * as beta from "beta";
        \\import * as betaAgain from "beta";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .import_no_duplicates = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_duplicate_imports.id));
}

test "reports no-duplicate-imports for separate type imports by default" {
    const source =
        \\import type { Foo } from "alpha";
        \\import { foo } from "alpha";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .import_no_duplicates = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_duplicate_imports.id));
}

test "supports configured no-duplicate-imports allowSeparateTypeImports" {
    const source =
        \\import type { Foo } from "alpha";
        \\import { foo } from "alpha";
        \\import type { Bar } from "beta";
        \\import type { Baz } from "beta";
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowSeparateTypeImports\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .import_no_duplicates = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("no-duplicate-imports", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_duplicate_imports.id));
}

test "can disable no-duplicate-imports" {
    const source =
        \\import foo from "alpha";
        \\import { bar } from "alpha";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .import_no_duplicates = false,
        .no_duplicate_imports = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_duplicate_imports.id));
}
