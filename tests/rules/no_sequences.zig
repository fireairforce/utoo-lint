const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-sequences for unparenthesized sequence expressions" {
    const source =
        \\foo = doSomething(), bar = foo;
        \\const arrow = () => (foo = doSomething(), foo);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_comma_operator = false,
        .no_self_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_sequences.id));
}

test "does not report no-sequences for allowed sequence expressions" {
    const source =
        \\const value = (foo = doSomething(), foo);
        \\const arrow = () => ((foo = doSomething(), foo));
        \\for (i = 0, j = 0; test; i++, j++) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_comma_operator = false,
        .no_self_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_sequences.id));
}

test "reports parenthesized sequences when configured" {
    const source =
        \\const value = (foo = doSomething(), foo);
        \\const arrow = () => ((foo = doSomething(), foo));
        \\for (i = 0, j = 0; test; i++, j++) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_sequences_allow_in_parentheses = .no,
        .no_comma_operator = false,
        .no_self_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_sequences.id));
}

test "can disable no-sequences" {
    const source =
        \\foo = doSomething(), bar = foo;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_sequences = false,
        .no_comma_operator = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_sequences.id));
}
