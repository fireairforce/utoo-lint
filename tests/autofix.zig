const std = @import("std");
const lint = @import("utoo_lint");

test "applies non-overlapping fixes in source order" {
    const source = "let first = 1;;\nlet second = 2;;\n";
    var first_fixes = [_]lint.Fix{.{
        .span = .{ .start = 14, .end = 15 },
        .replacement = "",
    }};
    var second_fixes = [_]lint.Fix{.{
        .span = .{ .start = 31, .end = 32 },
        .replacement = "",
    }};
    const diagnostics = [_]lint.Diagnostic{
        diagnostic("first", first_fixes[0..]),
        diagnostic("second", second_fixes[0..]),
    };

    var result = try lint.applyFixes(std.testing.allocator, source, &diagnostics);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqual(@as(usize, 2), result.applied_diagnostics);
    try std.testing.expectEqualStrings("let first = 1;\nlet second = 2;\n", result.output);
}

test "defers an overlapping diagnostic as one atomic fix group" {
    const source = "abcdef";
    var first_fixes = [_]lint.Fix{.{
        .span = .{ .start = 1, .end = 4 },
        .replacement = "X",
    }};
    var second_fixes = [_]lint.Fix{
        .{ .span = .{ .start = 0, .end = 1 }, .replacement = "A" },
        .{ .span = .{ .start = 3, .end = 5 }, .replacement = "Y" },
    };
    const diagnostics = [_]lint.Diagnostic{
        diagnostic("first", first_fixes[0..]),
        diagnostic("second", second_fixes[0..]),
    };

    var result = try lint.applyFixes(std.testing.allocator, source, &diagnostics);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), result.applied_diagnostics);
    try std.testing.expectEqualStrings("AbcYf", result.output);
}

test "skips invalid fix ranges" {
    const source = "value";
    var fixes = [_]lint.Fix{.{
        .span = .{ .start = 0, .end = 99 },
        .replacement = "other",
    }};
    const diagnostics = [_]lint.Diagnostic{diagnostic("invalid", fixes[0..])};

    var result = try lint.applyFixes(std.testing.allocator, source, &diagnostics);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqual(@as(usize, 0), result.applied_diagnostics);
    try std.testing.expectEqualStrings(source, result.output);
}

test "lintSourceAndFix returns final diagnostics after applying fixes" {
    const source = "const value = 1;;;";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_extra_semi = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqual(@as(usize, 1), result.passes);
    try std.testing.expectEqualStrings("const value = 1;", result.output);
    for (result.result.diagnostics) |diagnostic_item| {
        try std.testing.expect(!std.mem.eql(u8, diagnostic_item.rule_id, "no-extra-semi"));
    }
}

test "converts byte offsets to ESLint UTF-16 offsets" {
    const source = "a😀中";

    try std.testing.expectEqual(@as(usize, 1), lint.offsetToUtf16Offset(source, 1));
    try std.testing.expectEqual(@as(usize, 3), lint.offsetToUtf16Offset(source, 5));
    try std.testing.expectEqual(@as(usize, 4), lint.offsetToUtf16Offset(source, 8));
}

fn diagnostic(rule_id: []const u8, fixes: []lint.Fix) lint.Diagnostic {
    return .{
        .rule_id = rule_id,
        .message = "message",
        .span = .{ .start = 0, .end = 1 },
        .severity = .warning,
        .fixes = fixes,
    };
}
