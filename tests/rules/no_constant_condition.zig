const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-constant-condition for constant boolean contexts" {
    const source =
        \\if ((true)) { use(); }
        \\while ("ready") { break; }
        \\do { break; } while (`ready`);
        \\for (; /ready/; ) { break; }
        \\const value = null ? 1 : 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_constant_condition.id));
}

test "does not report no-constant-condition for dynamic conditions" {
    const source =
        \\if (ready) { use(); }
        \\while (`${ready}`) { break; }
        \\for (; ready; ) { break; }
        \\const value = ready ? 1 : 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_constant_condition.id));
}

test "does not report no-constant-condition for while true loops" {
    const source =
        \\while (true) { break; }
        \\while ((true)) { break; }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_constant_condition.id));
}

test "still reports no-constant-condition for other loop constants" {
    const source =
        \\while (false) { break; }
        \\while (1) { break; }
        \\do { break; } while (true);
        \\for (; true; ) { break; }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_constant_condition.id));
}

test "reports no-constant-condition for constant unary expressions" {
    const source =
        \\if (void 0) { use(); }
        \\if (!void 0) { use(); }
        \\if (+1) { use(); }
        \\if (-1) { use(); }
        \\if (~0) { use(); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_constant_condition.id));
}

test "does not report no-constant-condition for dynamic unary expressions" {
    const source =
        \\if (+ready) { use(); }
        \\if (-ready) { use(); }
        \\if (~ready) { use(); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_constant_condition.id));
}

test "reports no-constant-condition for constant logical expressions" {
    const source =
        \\if (true || ready) { use(); }
        \\if (ready || true) { use(); }
        \\if (false && ready) { use(); }
        \\if (ready && false) { use(); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_constant_condition.id));
}

test "does not report no-constant-condition for dynamic logical expressions" {
    const source =
        \\if (true && ready) { use(); }
        \\if (false || ready) { use(); }
        \\if (ready && true) { use(); }
        \\if (ready || false) { use(); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_constant_condition.id));
}

test "can disable no-constant-condition" {
    const source =
        \\if (false) { use(); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_constant_condition.id));
}
