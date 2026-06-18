const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-escape for unnecessary string and template escapes" {
    const source =
        \\const a = "\#";
        \\const b = '\"';
        \\const c = `\#`;
        \\const d = `\a ${value}`;
        \\const e = `\{literal}`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_useless_escape.id));
}

test "reports no-useless-escape for unnecessary regular expression escapes" {
    const source =
        \\const a = /\#/;
        \\const b = /[\#]/;
        \\const c = /\-/;
        \\const d = /[\-]/;
        \\const e = /[a\-]/;
        \\const f = /[\-a]/;
        \\const g = /[a\-z\-]/;
        \\const h = /[^\^]/;
        \\const i = /[a\^]/;
        \\const j = /[\]\-\^]/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 10), helpers.countRule(result, lint.rules.no_useless_escape.id));
}

test "supports configured no-useless-escape allowRegexCharacters" {
    const source =
        \\const a = /\#/;
        \\const b = /[\#]/;
        \\const c = /\-/;
        \\const d = /[\-]/;
        \\const e = /\@/;
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowRegexCharacters\":[\"#\",\"-\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("no-useless-escape", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_useless_escape.id));
}

test "does not report no-useless-escape for necessary escapes" {
    const source =
        \\const a = "\"";
        \\const b = '\'';
        \\const c = "\\";
        \\const d = "\n\t\x20\u0020";
        \\const e = `\`${value}\${literal}`;
        \\const f = /\d+\.\w+\/x/;
        \\const h = /[a\-z]/;
        \\const i = /[\^]/;
        \\const j = /[\^a]/;
        \\const k = `$\{literal}`;
        \\const l = tag`\# ${value}`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_escape.id));
}

test "can disable no-useless-escape" {
    const source =
        \\const a = "\#";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_escape = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_escape.id));
}
