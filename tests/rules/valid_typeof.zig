const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports valid-typeof for invalid typeof comparison strings" {
    const source =
        \\if (typeof value === "strnig") { use(value); }
        \\if (typeof value === `strnig`) { use(value); }
        \\if ("undefimed" !== typeof value) { use(value); }
        \\if ((typeof value) == ("bool")) { use(value); }
        \\if (typeof value === undefined) { use(value); }
        \\if (typeof value === null) { use(value); }
        \\if (typeof value === 1) { use(value); }
        \\if (typeof value === true) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eqeqeq = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 8), helpers.countRule(result, lint.rules.valid_typeof.id));
}

test "does not report valid-typeof for valid values or unrelated comparisons" {
    const source =
        \\const suffix = "nig";
        \\if (typeof value === "undefined") { use(value); }
        \\if (typeof value === `string`) { use(value); }
        \\if (typeof value === `str${suffix}`) { use(value); }
        \\if (typeof value !== "object") { use(value); }
        \\if (typeof value === "boolean") { use(value); }
        \\if (typeof value === "number") { use(value); }
        \\if (typeof value === "string") { use(value); }
        \\if (typeof value === "function") { use(value); }
        \\if (typeof value === "symbol") { use(value); }
        \\if (typeof value === "bigint") { use(value); }
        \\if (typeof value === expectedType) { use(value); }
        \\if (typeof value === typeof other) { use(value); }
        \\if (value === "strnig") { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.valid_typeof.id));
}

test "can disable valid-typeof" {
    const source =
        \\if (typeof value === "strnig") { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .valid_typeof = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.valid_typeof.id));
}
