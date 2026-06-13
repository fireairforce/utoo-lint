const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-children-prop for JSX children attributes and nested functions" {
    const source =
        \\const prop = <Box children={<span />} />;
        \\const boolProp = <Box children />;
        \\const functionChild = <Box>{() => <span />}</Box>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .import_newline_after_import = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_children_prop.id));
    try std.testing.expectEqualStrings(
        "Do not pass children as props. Instead, nest children between the opening and closing tags.",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqualStrings(
        "Do not nest a function between the opening and closing tags. Instead, pass it as a prop.",
        result.diagnostics[2].message,
    );
}

test "reports react/no-children-prop for createElement props and function children" {
    const source =
        \\import { createElement } from "react";
        \\const a = React.createElement("div", { children: text });
        \\const b = createElement("div", { children });
        \\const c = createElement("div", {}, () => null);
        \\const { createElement: other } = React;
        \\const d = other("div", { children: text });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .import_newline_after_import = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_children_prop.id));
    try std.testing.expectEqualStrings(
        "Do not pass children as props. Instead, pass them as additional arguments to React.createElement.",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqualStrings(
        "Do not pass a function as an additional argument to React.createElement. Instead, pass it as a prop.",
        result.diagnostics[2].message,
    );
}

test "detects destructured and require createElement bindings" {
    const source =
        \\{
        \\  const { createElement } = React;
        \\  const a = createElement("div", { children: text });
        \\}
        \\{
        \\  const createElement = require("react").createElement;
        \\  const b = createElement("div", { children: text });
        \\}
        \\{
        \\  const { createElement } = require("react");
        \\  const c = createElement("div", { children: text });
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_children_prop.id));
}

test "allows regular children nesting and non-react createElement calls" {
    const source =
        \\const nested = <Box><span /></Box>;
        \\const text = <Box>hello</Box>;
        \\const fnProp = <Box render={() => <span />} />;
        \\const local = createElement("div", { children: text });
        \\const stringKey = React.createElement("div", { "children": text });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_children_prop.id));
}

test "ignores type-only createElement imports" {
    const source =
        \\import type { createElement } from "react";
        \\const local = createElement("div", { children: text });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .import_newline_after_import = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_children_prop.id));
}

test "can disable react/no-children-prop" {
    const source =
        \\const prop = <Box children={<span />} />;
        \\const child = React.createElement("div", { children: text });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_no_children_prop = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_children_prop.id));
}
