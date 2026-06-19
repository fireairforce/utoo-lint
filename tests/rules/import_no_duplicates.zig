const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports import/no-duplicates for repeated module sources" {
    const source =
        \\import foo from "alpha";
        \\import { bar } from "alpha";
        \\import "beta";
        \\import "beta";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.import_no_duplicates.id));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, lint.rules.no_duplicate_imports.id));
    try std.testing.expectEqualStrings("'alpha' imported multiple times.", result.diagnostics[0].message);
}

test "does not report import/no-duplicates for distinct module sources" {
    const source =
        \\import foo from "alpha";
        \\import { bar } from "beta";
        \\import "gamma";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_duplicates.id));
}

test "reports import/no-duplicates for repeated module sources with query strings by default" {
    const source =
        \\import view from "./template?raw";
        \\import compiled from "./template?compiled";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.import_no_duplicates.id));
}

test "supports configured import/no-duplicates considerQueryString option" {
    const source =
        \\import view from "./template?raw";
        \\import compiled from "./template?compiled";
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"considerQueryString\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("import/no-duplicates", config.value);
    options.parser_semantic_errors = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_duplicates.id));
}

test "falls back to no-duplicate-imports when import/no-duplicates is disabled" {
    const source =
        \\import foo from "alpha";
        \\import { bar } from "alpha";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .import_no_duplicates = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_duplicates.id));
    try std.testing.expect(helpers.hasRule(result, lint.rules.no_duplicate_imports.id));
}
