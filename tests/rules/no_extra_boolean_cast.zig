const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-extra-boolean-cast in boolean contexts" {
    const source =
        \\if (Boolean(value)) { use(value); }
        \\while (!!value) { break; }
        \\do { value++; } while (Boolean(value));
        \\for (; !!value; value++) { break; }
        \\const selected = Boolean(value) ? 1 : 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_extra_boolean_cast.id));
}

test "does not report no-extra-boolean-cast outside boolean contexts or for shadowed Boolean" {
    const source =
        \\const a = Boolean(value);
        \\const b = !!value;
        \\function local(Boolean) {
        \\  if (Boolean(value)) { use(value); }
        \\}
        \\if (!value) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_boolean_cast.id));
}

test "can disable no-extra-boolean-cast" {
    const source =
        \\if (Boolean(value)) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_extra_boolean_cast = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_boolean_cast.id));
}
