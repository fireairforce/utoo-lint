const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-multi-str for string line continuations" {
    const source =
        "const first = 'line \\\n" ++
        "continued';\n" ++
        "const second = \"line \\\r\n" ++
        "continued\";\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_multi_str.id));
}

test "does not report no-multi-str for escaped newline sequences or template literals" {
    const source =
        \\const escaped = "line\ncontinued";
        \\const template = `line
        \\continued`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_multi_str.id));
}

test "can disable no-multi-str" {
    const source =
        "const value = 'line \\\n" ++
        "continued';\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_multi_str = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_multi_str.id));
}
