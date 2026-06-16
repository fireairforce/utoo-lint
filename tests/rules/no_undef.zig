const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-undef for missing references" {
    const source =
        \\const value = missing;
        \\console.log(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{});
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.no_undef.id));
}

test "does not report no-undef for direct typeof identifier operands by default" {
    const source =
        \\typeof missing;
        \\typeof (alsoMissing);
        \\typeof missing === "undefined";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_undef.id));
}

test "reports no-undef for unresolved member objects inside typeof" {
    const source =
        \\typeof missing.prop;
        \\typeof (alsoMissing.prop);
        \\missing.prop;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_undef.id));
}
