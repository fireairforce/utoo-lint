const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const test_options = lint.Options{
    .no_undef = false,
    .no_unused_vars = false,
    .typescript_eslint_no_unused_vars = false,
};

test "reports undefined JSX component names" {
    const source =
        \\const one = <Missing />;
        \\const two = <UI.Widget />;
        \\const three = <Promise />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_jsx_no_undef.id));
}

test "does not report DOM tags namespaced JSX or declared components" {
    const source =
        \\import Imported from "pkg";
        \\const Local = () => null;
        \\const one = <div />;
        \\const two = <svg:path />;
        \\const three = <Local />;
        \\const four = <Imported />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_no_undef.id));
}

test "can disable react jsx no undef" {
    const source = "const one = <Missing />;";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .react_jsx_no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_no_undef.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_undef.id));
}

test "does not duplicate core no undef diagnostics for JSX identifiers" {
    const source = "const one = <Missing />;";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_no_undef.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_undef.id));
}
