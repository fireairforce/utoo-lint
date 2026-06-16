const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-rename for same-name import export and destructuring aliases" {
    const source =
        \\import { foo as foo } from "mod";
        \\export { foo as foo };
        \\const { bar: bar, baz: baz = fallback } = source;
        \\({ qux: qux } = source);
        \\({ value: value = fallback } = source);
        \\({ nested: { prop: prop } } = source);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_useless_rename.id));
}

test "does not report no-useless-rename for meaningful aliases or shorthand" {
    const source =
        \\import { foo as bar, baz } from "mod";
        \\export { foo as bar };
        \\const { foo: bar, baz } = source;
        \\({ qux: alias } = source);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_rename.id));
}

test "can disable no-useless-rename" {
    const source =
        \\import { foo as foo } from "mod";
        \\const { bar: bar } = source;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_rename = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_rename.id));
}
