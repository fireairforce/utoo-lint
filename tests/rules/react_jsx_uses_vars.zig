const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "marks JSX component variables as used" {
    const source =
        \\const Component = () => null;
        \\export const node = <Component />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "can disable react jsx uses vars" {
    const source =
        \\const Component = () => null;
        \\export const node = <Component />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
        .react_jsx_uses_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "does not treat lowercase DOM JSX as variable usage" {
    const source =
        \\const div = 1;
        \\export const node = <div />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}
