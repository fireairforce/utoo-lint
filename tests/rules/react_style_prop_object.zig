const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/style-prop-object for JSX non-object style values" {
    const source =
        \\const color = "red";
        \\const stringAttr = <div style="color: red" />;
        \\const numberExpr = <div style={1} />;
        \\const identifierLiteral = <div style={color} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_style_prop_object.id));
    try std.testing.expectEqualStrings(
        "Style prop value must be an object",
        result.diagnostics[0].message,
    );
}

test "reports react/style-prop-object for createElement style literals" {
    const source =
        \\import { createElement } from "react";
        \\const color = "red";
        \\const a = React.createElement("div", { style: "color: red" });
        \\const b = createElement("div", { style: 1 });
        \\const c = createElement("div", { style: color });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .import_newline_after_import = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_style_prop_object.id));
}

test "allows object null and unresolved style values" {
    const source =
        \\const styles = { color: "red" };
        \\const jsxObject = <div style={styles} />;
        \\const jsxInline = <div style={{ color: "red" }} />;
        \\const jsxNull = <div style={null} />;
        \\const jsxUnknown = <div style={unknown} />;
        \\const callObject = React.createElement("div", { style: styles });
        \\const callInline = React.createElement("div", { style: { color: "red" } });
        \\const callNull = React.createElement("div", { style: null });
        \\const callUnknown = React.createElement("div", { style: unknown });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_style_prop_object.id));
}

test "detects destructured and require createElement bindings" {
    const source =
        \\{
        \\  const { createElement } = React;
        \\  const a = createElement("div", { style: "color: red" });
        \\}
        \\{
        \\  const createElement = require("react").createElement;
        \\  const b = createElement("div", { style: 1 });
        \\}
        \\{
        \\  const { createElement } = require("react");
        \\  const c = createElement("div", { style: true });
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_style_prop_object.id));
}

test "can disable react/style-prop-object" {
    const source =
        \\const jsx = <div style="color: red" />;
        \\const call = React.createElement("div", { style: "color: red" });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_style_prop_object = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_style_prop_object.id));
}
