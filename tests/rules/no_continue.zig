const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-continue for continue statements" {
    const source =
        "for (let i = 0; i < 3; i++) {\n" ++
        "  if (i === 1) continue;\n" ++
        "}\n" ++
        "outer: for (let j = 0; j < 3; j++) {\n" ++
        "  continue outer;\n" ++
        "}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .no_plusplus = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_continue.id));
    try std.testing.expectEqualStrings(
        "Unexpected use of continue statement.",
        result.diagnostics[0].message,
    );
}

test "does not report no-continue for break statements" {
    const source =
        "for (let i = 0; i < 3; i++) {\n" ++
        "  if (i === 1) break;\n" ++
        "}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .no_plusplus = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_continue.id));
}

test "can disable no-continue" {
    const source = "for (let i = 0; i < 3; i++) { continue; }\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_continue = false,
        .no_plusplus = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_continue.id));
}
