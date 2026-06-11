const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports unicode-bom when source starts with a byte order mark" {
    const source = "\xEF\xBB\xBFconst value = 1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.unicode_bom.id));
    try std.testing.expectEqualStrings(
        "Unexpected Unicode BOM (Byte Order Mark).",
        result.diagnostics[0].message,
    );
}

test "does not report unicode-bom for ordinary source" {
    const source = "const value = 1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.unicode_bom.id));
}

test "can disable unicode-bom" {
    const source = "\xEF\xBB\xBFconst value = 1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .unicode_bom = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.unicode_bom.id));
}
