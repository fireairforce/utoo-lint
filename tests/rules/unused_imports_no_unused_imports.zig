const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports unused default named namespace and type-only imports" {
    const source =
        \\import unusedDefault from "default-package";
        \\import { unusedNamed, usedNamed } from "named-package";
        \\import * as unusedNamespace from "namespace-package";
        \\import type { UnusedType, UsedType } from "type-package";
        \\type Alias = UsedType;
        \\console.log(usedNamed);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.unused_imports_no_unused_imports.id));
}

test "keeps side-effect imports and JSX references" {
    const source =
        \\import Component from "component";
        \\import "side-effect";
        \\export const view = <Component />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.unused_imports_no_unused_imports.id));
}

test "autofix removes only unused bindings from a multiline import" {
    const source =
        \\import unusedDefault, {
        \\  used,
        \\  // keep this comment
        \\  unusedNamed,
        \\  usedToo,
        \\} from "package";
        \\console.log(used, usedToo);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.unused_imports_no_unused_imports.id));

    var applied = try lint.applyFixes(std.testing.allocator, source, result.diagnostics);
    defer applied.deinit(std.testing.allocator);

    try std.testing.expect(applied.fixed);
    try std.testing.expect(std.mem.indexOf(u8, applied.output, "unusedDefault") == null);
    try std.testing.expect(std.mem.indexOf(u8, applied.output, "unusedNamed") == null);
    try std.testing.expect(std.mem.indexOf(u8, applied.output, "// keep this comment") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.output, "usedToo") != null);

    var fixed_result = try lint.lintSource(std.testing.allocator, applied.output, "fixture.js", ruleOptions());
    defer fixed_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), fixed_result.diagnostics.len);
}

test "autofix removes an empty declaration but preserves comments and side effects" {
    const source =
        \\import /* keep block */ {
        \\  // keep line
        \\  unused
        \\} from "package";
        \\import "side-effect";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    var applied = try lint.applyFixes(std.testing.allocator, source, result.diagnostics);
    defer applied.deinit(std.testing.allocator);

    try std.testing.expect(applied.fixed);
    try std.testing.expect(std.mem.indexOf(u8, applied.output, "unused") == null);
    try std.testing.expect(std.mem.indexOf(u8, applied.output, "\"package\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, applied.output, "/* keep block */") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.output, "// keep line") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.output, "import \"side-effect\"") != null);

    var fixed_result = try lint.lintSource(std.testing.allocator, applied.output, "fixture.js", ruleOptions());
    defer fixed_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), fixed_result.diagnostics.len);
}

test "autofix leaves deleted import lines free of spaces and tabs" {
    const cases = [_]struct {
        source: []const u8,
        expected: []const u8,
    }{
        .{
            .source = "import { Clean } from \"./clean\";\n\nexport const value = 1;",
            .expected = "\n\nexport const value = 1;",
        },
        .{
            .source = "\timport Unused from \"package\"; \t\nexport const value = 1;",
            .expected = "\nexport const value = 1;",
        },
        .{
            .source = "import * as Unused from \"package\";   // keep trailing\nexport const value = 1;",
            .expected = "// keep trailing\nexport const value = 1;",
        },
    };

    for (cases) |case| {
        var result = try lint.lintSourceAndFix(std.testing.allocator, case.source, "fixture.ts", ruleOptions());
        defer result.deinit(std.testing.allocator);

        try std.testing.expect(result.fixed);
        try std.testing.expectEqualStrings(case.expected, result.output);
        var lines = std.mem.splitScalar(u8, result.output, '\n');
        while (lines.next()) |line| {
            if (std.mem.trim(u8, line, " \t").len == 0) {
                try std.testing.expectEqual(@as(usize, 0), line.len);
            }
        }
        try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result.result, "parse"));
    }
}

test "unused import autofix is idempotent" {
    const source =
        \\import UnusedDefault from "default-package";
        \\import { Used, UnusedNamed } from "named-package";
        \\console.log(Used);
    ;

    var first = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer first.deinit(std.testing.allocator);
    try std.testing.expect(first.fixed);

    var second = try lint.lintSourceAndFix(std.testing.allocator, first.output, "fixture.js", ruleOptions());
    defer second.deinit(std.testing.allocator);
    try std.testing.expect(!second.fixed);
    try std.testing.expectEqual(@as(usize, 0), second.passes);
    try std.testing.expectEqualStrings(first.output, second.output);
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(second.result, "parse"));
}

test "autofix keeps mixed import forms syntactically valid" {
    const cases = [_]struct {
        source: []const u8,
        removed: []const u8,
        preserved: []const u8,
    }{
        .{
            .source = "import used, * as unusedNamespace from \"package\";\nconsole.log(used);",
            .removed = "unusedNamespace",
            .preserved = "used",
        },
        .{
            .source = "import used, { /* keep named comment */ unusedNamed } from \"package\";\nconsole.log(used);",
            .removed = "unusedNamed",
            .preserved = "/* keep named comment */",
        },
        .{
            .source = "import { used, unusedOne, unusedTwo, } from \"package\";\nconsole.log(used);",
            .removed = "unusedOne",
            .preserved = "used",
        },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, "fixture.js", ruleOptions());
        defer result.deinit(std.testing.allocator);

        var applied = try lint.applyFixes(std.testing.allocator, case.source, result.diagnostics);
        defer applied.deinit(std.testing.allocator);

        try std.testing.expect(applied.fixed);
        try std.testing.expect(std.mem.indexOf(u8, applied.output, case.removed) == null);
        try std.testing.expect(std.mem.indexOf(u8, applied.output, case.preserved) != null);

        var fixed_result = try lint.lintSource(std.testing.allocator, applied.output, "fixture.js", ruleOptions());
        defer fixed_result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), fixed_result.diagnostics.len);
    }
}

test "takes ownership of import diagnostics when no-unused-vars is also enabled" {
    var options = lint.Options.allDisabled();
    options.unused_imports_no_unused_imports = true;
    options.no_unused_vars = true;

    var result = try lint.lintSource(std.testing.allocator, "import unused from \"package\";", "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.unused_imports_no_unused_imports.id));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, lint.rules.no_unused_vars.id));
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.unused_imports_no_unused_imports = true;
    return options;
}
