const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("helpers.zig");

test "utlint-ignore suppresses a rule diagnostic on the next line" {
    const source =
        \\// utlint-ignore no-debugger: generated breakpoint
        \\debugger;
        \\debugger;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_debugger.id));
    try std.testing.expectEqual(@as(usize, 1), result.suppressed_diagnostics.len);
    try std.testing.expectEqualStrings(lint.rules.no_debugger.id, result.suppressed_diagnostics[0].rule_id);
    try std.testing.expectEqualStrings("generated breakpoint", result.suppressed_diagnostics[0].suppression.?.justification);
}

test "utlint-ignore targets the next line of code across blank and comment lines" {
    const source =
        \\// utlint-ignore no-debugger: generated breakpoint
        \\
        \\// Kept next to the generated statement.
        \\debugger;
        \\debugger;
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_debugger.id));
}

test "utlint-ignore does not skip over an intervening line of code" {
    const source =
        \\// utlint-ignore no-debugger: applies to the declaration
        \\const value = 1;
        \\debugger;
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_debugger.id));
}

test "utlint-ignore works in block comments" {
    const source =
        \\/* utlint-ignore no-debugger: generated breakpoint */
        \\debugger;
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), result.diagnostics.len);
    try std.testing.expectEqual(@as(usize, 1), result.suppressed_diagnostics.len);
}

test "utlint-ignore text inside a string is not a directive" {
    const source =
        \\const text = "// utlint-ignore no-debugger: not a comment";
        \\debugger;
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_debugger.id));
}

test "utlint-ignore suppresses all rule diagnostics when no rule is named" {
    const source =
        \\// utlint-ignore: generated code
        \\debugger; console.log("generated");
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;
    options.no_console = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), result.diagnostics.len);
}

test "suppression directives do not violate capitalized-comments" {
    const source =
        \\// utlint-ignore no-debugger: generated breakpoint
        \\debugger;
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;
    options.capitalized_comments = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), result.diagnostics.len);
}

test "suppression comments do not hide parse diagnostics" {
    const source =
        \\// utlint-ignore: invalid generated syntax
        \\const = ;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", lint.Options.allDisabled());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, "parse"));
}

test "autofix does not apply fixes from suppressed diagnostics" {
    const source =
        \\// utlint-ignore no-extra-semi: generated statement
        \\const value = 1;;
    ;

    var options = lint.Options.allDisabled();
    options.no_extra_semi = true;

    var fixed = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer fixed.deinit(std.testing.allocator);

    try std.testing.expect(!fixed.fixed);
    try std.testing.expectEqualStrings(source, fixed.output);
    try std.testing.expectEqual(@as(usize, 1), fixed.result.suppressed_diagnostics.len);
}

test "overlapping ESLint directives preserve every suppression" {
    const source =
        \\/* eslint-disable no-extra-semi -- generated */
        \\const value = 1;; // eslint-disable-line no-extra-semi -- intentional
        \\void value;
    ;

    var options = lint.Options.allDisabled();
    options.no_extra_semi = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), result.diagnostics.len);
    try std.testing.expectEqual(@as(usize, 1), result.suppressed_diagnostics.len);
    const suppressions = result.suppressed_diagnostics[0].suppressions;
    try std.testing.expectEqual(@as(usize, 2), suppressions.len);
    try std.testing.expectEqualStrings("generated", suppressions[0].justification);
    try std.testing.expectEqualStrings("intentional", suppressions[1].justification);
    try std.testing.expectEqualStrings("intentional", result.suppressed_diagnostics[0].suppression.?.justification);
}

test "ESLint directive accepts an empty justification after a separator" {
    const source =
        \\/* eslint-disable no-extra-semi -- */
        \\const value = 1;;
        \\void value;
    ;

    var options = lint.Options.allDisabled();
    options.no_extra_semi = true;

    var fixed = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer fixed.deinit(std.testing.allocator);

    try std.testing.expect(!fixed.fixed);
    try std.testing.expectEqualStrings(source, fixed.output);
    try std.testing.expectEqual(@as(usize, 1), fixed.result.suppressed_diagnostics.len);
    try std.testing.expectEqualStrings("", fixed.result.suppressed_diagnostics[0].suppression.?.justification);
}

test "overlapping utlint and ESLint directives preserve both suppressions" {
    const source =
        \\/* eslint-disable no-extra-semi -- generated */
        \\// utlint-ignore no-extra-semi: intentional
        \\const value = 1;;
        \\void value;
    ;

    var options = lint.Options.allDisabled();
    options.no_extra_semi = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), result.suppressed_diagnostics.len);
    const suppressions = result.suppressed_diagnostics[0].suppressions;
    try std.testing.expectEqual(@as(usize, 2), suppressions.len);
    try std.testing.expectEqualStrings("generated", suppressions[0].justification);
    try std.testing.expectEqualStrings("intentional", suppressions[1].justification);
    try std.testing.expectEqualStrings("intentional", result.suppressed_diagnostics[0].suppression.?.justification);
}

test "utlint-ignore-all suppresses a named rule throughout the file" {
    const source =
        \\// utlint-ignore-all no-debugger: generated file
        \\debugger;
        \\debugger; console.log("still linted");
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;
    options.no_console = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, lint.rules.no_debugger.id));
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_console.id));
}

test "utlint-ignore-all remains top-level after a shebang" {
    const source =
        \\#!/usr/bin/env node
        \\// utlint-ignore-all no-debugger: generated executable
        \\debugger;
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, lint.rules.no_debugger.id));
}

test "utlint-ignore-all suppresses all rules after a BOM and leading comments" {
    const source =
        "\xef\xbb\xbf" ++
        "// Generated file.\n" ++
        "/* utlint-ignore-all: generated file */\n" ++
        "debugger; console.log(\"generated\");\n";

    var options = lint.Options.allDisabled();
    options.no_debugger = true;
    options.no_console = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), result.diagnostics.len);
    try std.testing.expectEqual(@as(usize, 2), result.suppressed_diagnostics.len);
    try std.testing.expectEqualStrings("generated file", result.suppressed_diagnostics[0].suppression.?.justification);
}

test "utlint-ignore-all is ignored when it appears after code" {
    const source =
        \\debugger;
        \\// utlint-ignore-all no-debugger: too late
        \\debugger;
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_debugger.id));
}

test "utlint-ignore-start and utlint-ignore-end suppress a named rule in a range" {
    const source =
        \\debugger;
        \\// utlint-ignore-start no-debugger: generated section
        \\debugger; console.log("still linted");
        \\// utlint-ignore-end no-debugger: generated section
        \\debugger;
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;
    options.no_console = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_debugger.id));
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_console.id));
}

test "nested suppression ranges stay active until their matching ends" {
    const source =
        \\// utlint-ignore-start no-debugger: outer generated section
        \\// utlint-ignore-start no-debugger: inner generated section
        \\debugger;
        \\// utlint-ignore-end no-debugger: inner generated section
        \\debugger;
        \\// utlint-ignore-end no-debugger: outer generated section
        \\debugger;
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_debugger.id));
}

test "a named range end does not close an all-rules range" {
    const source =
        \\// utlint-ignore-start: generated section
        \\debugger;
        \\// utlint-ignore-end no-debugger: unrelated range end
        \\debugger;
        \\// utlint-ignore-end: generated section
        \\debugger;
    ;

    var options = lint.Options.allDisabled();
    options.no_debugger = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_debugger.id));
}
