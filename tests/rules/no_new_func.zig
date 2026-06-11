const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-new-func for Function constructor usage" {
    const source =
        \\const a = new Function("return 1");
        \\const b = Function("return 1");
        \\const c = Function.call(null, "return 1");
        \\const d = Function.apply(null, ["return 1"]);
        \\const e = Function.bind(null, "return 1");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_new_func.id));
}

test "does not report no-new-func for shadowed Function" {
    const source =
        \\function local(Function) {
        \\  const a = new Function("return 1");
        \\  const b = Function("return 1");
        \\  const c = Function.call(null, "return 1");
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_new_func.id));
}

test "can disable no-new-func" {
    const source =
        \\const a = new Function("return 1");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new_func = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_new_func.id));
}
