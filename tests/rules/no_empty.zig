const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-empty for empty block statements" {
    const source =
        \\if (ready) {}
        \\while (ready) {
        \\}
        \\try {} catch (error) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_empty.id));
    try std.testing.expectEqualStrings("Empty block statement.", result.diagnostics[0].message);
}

test "does not report no-empty for non-empty or commented blocks" {
    const source =
        \\if (ready) { run(); }
        \\if (waiting) { /* empty */ }
        \\try { work(); } catch (error) {
        \\  // ignored
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty.id));
}

test "can disable no-empty" {
    const source =
        \\if (ready) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty.id));
}
