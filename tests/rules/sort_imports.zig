const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports unsorted import declarations" {
    const source =
        \\import z from "z";
        \\import * as ns from "ns";
        \\import { a } from "a";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.sort_imports.id));
}

test "reports unsorted named members" {
    const source =
        \\import { zebra, alpha, beta } from "animals";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.sort_imports.id));
}

test "supports ignoreCase" {
    const source =
        \\import { alpha, Beta } from "letters";
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer default_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.sort_imports.id));

    var options = optionsOnly();
    options.sort_imports_ignore_case = true;
    var ignored_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer ignored_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(ignored_result, lint.rules.sort_imports.id));
}

test "supports ignore declaration and member sorting" {
    const member_source =
        \\import { zebra, alpha } from "animals";
        \\import z from "z";
    ;

    var declaration_options = optionsOnly();
    declaration_options.sort_imports_ignore_declaration_sort = true;
    var declaration_result = try lint.lintSource(std.testing.allocator, member_source, "fixture.js", declaration_options);
    defer declaration_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(declaration_result, lint.rules.sort_imports.id));

    const declaration_source =
        \\import z from "z";
        \\import a from "a";
    ;

    var member_options = optionsOnly();
    member_options.sort_imports_ignore_member_sort = true;
    var member_result = try lint.lintSource(std.testing.allocator, declaration_source, "fixture.js", member_options);
    defer member_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(member_result, lint.rules.sort_imports.id));
}

test "supports allowSeparatedGroups" {
    const source =
        \\import z from "z";
        \\
        \\import a from "a";
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer default_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.sort_imports.id));

    var options = optionsOnly();
    options.sort_imports_allow_separated_groups = true;
    var grouped_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer grouped_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(grouped_result, lint.rules.sort_imports.id));
}

test "parses memberSyntaxSortOrder" {
    const source =
        \\import local from "local";
        \\import { a, b } from "named";
    ;

    const options = try optionsWithConfig(
        "[\"error\",{\"memberSyntaxSortOrder\":[\"single\",\"multiple\",\"all\",\"none\"]}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.sort_imports.id));
    try std.testing.expectEqual(lint.SortImportsMemberSyntax.single, options.sort_imports_member_syntax_order.values[0]);
}

test "can disable sort-imports" {
    const source =
        \\import z from "z";
        \\import a from "a";
    ;

    var options = optionsOnly();
    options.sort_imports = false;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.sort_imports.id));
}

fn optionsWithConfig(config: []const u8) !lint.Options {
    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue("sort-imports", parsed.value);
    return options;
}

fn optionsOnly() lint.Options {
    var options = baseOptions();
    options.sort_imports = true;
    return options;
}

fn baseOptions() lint.Options {
    return .{
        .import_no_unresolved = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unassigned_vars = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}
