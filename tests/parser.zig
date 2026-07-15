const std = @import("std");
const lint = @import("utoo_lint");

test "accepts reserved words as TypeScript type references" {
    // TypeScript parses reserved words in type positions before semantic resolution
    var result = try lint.lintSource(
        std.testing.allocator,
        "type T = break;",
        "fixture.ts",
        lint.Options.allDisabled(),
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), result.diagnostics.len);
}

test "accepts U+0085 as TypeScript whitespace" {
    // tsc treats U+0085 as whitespace without making it a line terminator
    var result = try lint.lintSource(
        std.testing.allocator,
        "var value =\u{0085}0;",
        "fixture.ts",
        lint.Options.allDisabled(),
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), result.diagnostics.len);
}
