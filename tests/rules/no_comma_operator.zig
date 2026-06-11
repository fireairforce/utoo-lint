const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-comma-operator outside for init and update" {
    const source =
        \\const value = (doSomething(), 0);
        \\for (; doSomething(), test; ) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.no_comma_operator.id));
}

test "allows comma operator in for init and update" {
    const source =
        \\for (i = 0, j = 0; test; i++, j++) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_comma_operator.id));
}

test "can disable no-comma-operator" {
    const source =
        \\const value = (doSomething(), 0);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_comma_operator = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_comma_operator.id));
}
