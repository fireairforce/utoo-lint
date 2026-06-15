const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-implied-eval for string timer and execScript calls" {
    const source =
        \\setTimeout("alert(1)", 100);
        \\setInterval(`tick()`, 100);
        \\execScript("alert(1)");
        \\globalThis.setTimeout("alert(1)");
        \\globalThis["setInterval"]("tick()", 100);
        \\globalThis[`setInterval`]("tick()", 100);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_alert = false,
        .no_eval = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.no_implied_eval.id));
}

test "does not report no-implied-eval for function arguments or shadowed calls" {
    const source =
        \\setTimeout(() => alert(1), 100);
        \\setInterval(handler, 100);
        \\const setTimeout = customTimer;
        \\setTimeout("not global");
        \\const window = sandbox;
        \\window.setTimeout("not global");
        \\window.setInterval("not global");
        \\global.setTimeout("not global");
        \\self.setTimeout("not global");
        \\object.setInterval("not global");
        \\globalThis[`set${suffix}`]("not static");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_alert = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_implied_eval.id));
}

test "can disable no-implied-eval" {
    const source =
        \\setTimeout("alert(1)", 100);
        \\globalThis.setInterval("tick()", 100);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_implied_eval = false,
        .no_alert = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_implied_eval.id));
}
