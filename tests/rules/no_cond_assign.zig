const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-cond-assign for unparenthesized assignments in conditions" {
    const source =
        \\if (value = next) { use(value); }
        \\while (node = node.parentNode) { use(node); }
        \\do { use(value); } while (value += 1);
        \\for (; value ||= next; ) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_cond_assign.id));
}

test "does not report no-cond-assign for parenthesized assignments or comparisons" {
    const source =
        \\if ((value = next)) { use(value); }
        \\while ((node = node.parentNode) !== null) { use(node); }
        \\do { use(value); } while ((value += 1));
        \\for (; value === next; ) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_cond_assign.id));
}

test "can disable no-cond-assign" {
    const source =
        \\if (value = next) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_cond_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_cond_assign.id));
}
