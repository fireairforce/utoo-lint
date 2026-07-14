const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-rename for same-name import export and destructuring aliases" {
    const source =
        \\import { foo as foo } from "mod";
        \\export { foo as foo };
        \\const { bar: bar, baz: baz = fallback } = source;
        \\({ qux: qux } = source);
        \\({ value: value = fallback } = source);
        \\({ nested: { prop: prop } } = source);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_useless_rename.id));
}

test "does not report no-useless-rename for meaningful aliases or shorthand" {
    const source =
        \\import { foo as bar, baz } from "mod";
        \\export { foo as bar };
        \\const { foo: bar, baz } = source;
        \\({ qux: alias } = source);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_rename.id));
}

test "supports configured no-useless-rename ignore options" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreDestructuring\":true,\"ignoreImport\":true,\"ignoreExport\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-useless-rename", config.value);
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\import { foo as foo } from "mod";
        \\export { foo as foo };
        \\const { bar: bar, baz: baz = fallback } = source;
        \\({ qux: qux } = source);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_rename.id));
}

test "can disable no-useless-rename" {
    const source =
        \\import { foo as foo } from "mod";
        \\const { bar: bar } = source;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_rename = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_rename.id));
}

test "autofixes same-name aliases" {
    const source =
        \\import { foo as foo } from "mod";
        \\export { foo as foo };
        \\const { bar: bar, baz: baz = fallback } = source;
        \\({ qux: qux } = source);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\import { foo } from "mod";
        \\export { foo };
        \\const { bar, baz = fallback } = source;
        \\({ qux } = source);
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_useless_rename.id));
}

test "does not autofix aliases when replacement would discard comments" {
    const source =
        \\import { foo /* keep */ as foo } from "mod";
        \\const { bar: /* keep */ bar } = source;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result.result, lint.rules.no_useless_rename.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_useless_rename.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "autofixes parenthesized destructuring aliases to valid shorthand" {
    const source = "({ foo: (foo) } = source);";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("({ foo } = source);", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_useless_rename.id));
}
