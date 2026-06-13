const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/void-dom-elements-no-children for JSX children and props" {
    const source =
        \\const textChild = <br>text</br>;
        \\const childProp = <img children="alt" />;
        \\const danger = <input dangerouslySetInnerHTML={{ __html: html }} />;
        \\const both = <hr children="x">text</hr>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_no_children_prop = false,
        .react_no_danger = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.react_void_dom_elements_no_children.id));
    try std.testing.expectEqualStrings(
        "Void DOM element <br /> cannot receive children.",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqualStrings(
        "Void DOM element <hr /> cannot receive children.",
        result.diagnostics[4].message,
    );
}

test "reports react/void-dom-elements-no-children for createElement children and props" {
    const source =
        \\import { createElement } from "react";
        \\const argChild = React.createElement("br", {}, "text");
        \\const propChild = createElement("img", { children: "alt" });
        \\const propDanger = createElement("input", { dangerouslySetInnerHTML: { __html: html } });
        \\const both = createElement("hr", { children: "x" }, "text");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .import_newline_after_import = false,
        .react_no_children_prop = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.react_void_dom_elements_no_children.id));
    try std.testing.expectEqualStrings(
        "Void DOM element <br /> cannot receive children.",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqualStrings(
        "Void DOM element <hr /> cannot receive children.",
        result.diagnostics[4].message,
    );
}

test "detects destructured and require createElement bindings" {
    const source =
        \\{
        \\  const { createElement } = React;
        \\  const a = createElement("br", { children: text });
        \\}
        \\{
        \\  const createElement = require("react").createElement;
        \\  const b = createElement("img", { children: text });
        \\}
        \\{
        \\  const { createElement } = require("react");
        \\  const c = createElement("input", { dangerouslySetInnerHTML: { __html: html } });
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_no_children_prop = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_void_dom_elements_no_children.id));
}

test "allows non-void JSX elements non-react calls and unsupported prop shapes" {
    const source =
        \\const div = <div children="ok">text</div>;
        \\const custom = <Img children="ok" />;
        \\const spread = <br {...props} />;
        \\const local = createElement("br", { children: text });
        \\const nullPropsChild = React.createElement("br", null, "text");
        \\const stringKey = React.createElement("br", { "children": text });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_no_children_prop = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_void_dom_elements_no_children.id));
}

test "ignores type-only createElement imports" {
    const source =
        \\import type { createElement } from "react";
        \\const local = createElement("br", { children: text });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .import_newline_after_import = false,
        .react_no_children_prop = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_void_dom_elements_no_children.id));
}

test "can disable react/void-dom-elements-no-children" {
    const source =
        \\const child = <br>text</br>;
        \\const call = React.createElement("br", { children: text });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_void_dom_elements_no_children = false,
        .react_no_children_prop = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_void_dom_elements_no_children.id));
}
