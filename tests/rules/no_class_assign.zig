const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-class-assign for reassigned class bindings" {
    const source =
        \\class First {}
        \\First = replacement;
        \\class Second {}
        \\Second += replacement;
        \\class Third {}
        \\Third++;
        \\const value = class Named {
        \\  method() {
        \\    Named = replacement;
        \\  }
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_class_assign.id));
}

test "does not report no-class-assign for shadowed variables or member assignments" {
    const source =
        \\class First {}
        \\function wrapper(First) {
        \\  First = replacement;
        \\}
        \\{
        \\  let First = 1;
        \\  First = 2;
        \\}
        \\object.First = replacement;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_class_assign.id));
}

test "can disable no-class-assign" {
    const source =
        \\class First {}
        \\First = replacement;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_class_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_class_assign.id));
}
