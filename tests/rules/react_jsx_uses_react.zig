const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "marks React as used when JSX is present" {
    const source =
        \\import React from "react";
        \\
        \\const node = <div />;
        \\console.log(node);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "can disable react jsx uses react" {
    const source =
        \\import React from "react";
        \\
        \\const node = <div />;
        \\console.log(node);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
        .react_jsx_uses_react = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "marks custom jsx pragma as used" {
    const source =
        \\/** @jsx h */
        \\import h from "preact";
        \\
        \\const node = <div />;
        \\console.log(node);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "marks React and Fragment as used for JSX fragments" {
    const source =
        \\import React, { Fragment } from "react";
        \\
        \\const node = <>text</>;
        \\console.log(node);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}
