const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const test_options = lint.Options{
    .no_undef = false,
    .no_unused_vars = false,
    .typescript_eslint_no_unused_vars = false,
    .react_jsx_no_undef = false,
};

test "reports JSX key using array index parameter" {
    const source =
        \\items.map((item, index) => <Item key={index} value={item} />);
        \\items.filter((item, index) => <Item key={`item-${index}`} value={item} />);
        \\items.reduce((acc, item, index) => <Item key={"item-" + index} value={item} />, null);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_array_index_key.id));
}

test "reports String and toString index keys" {
    const source =
        \\items.map((item, index) => <Item key={index.toString()} value={item} />);
        \\items.map((item, index) => <Item key={String(index)} value={item} />);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_no_array_index_key.id));
}

test "reports createElement and cloneElement index keys" {
    const source =
        \\import { createElement, cloneElement as clone } from "react";
        \\
        \\items.map((item, index) => createElement(Item, { key: index, value: item }));
        \\items.map((item, index) => React.cloneElement(item, { key: index }));
        \\items.map((item, index) => clone(item, { key: index }));
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_array_index_key.id));
}

test "reports React Children index keys" {
    const source =
        \\React.Children.map(children, (child, index) => <Item key={index}>{child}</Item>);
        \\Children.forEach(children, (child, index) => <Item key={index}>{child}</Item>);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_no_array_index_key.id));
}

test "does not report non-index key values" {
    const source =
        \\items.map((item, index) => <Item key={item.id} value={index} />);
        \\items.map((item) => <Item key={item.id} />);
        \\items.map((item, index) => <Item key="static" value={index} />);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_array_index_key.id));
}

test "can disable react no array index key" {
    const source = "items.map((item, index) => <Item key={index} value={item} />);";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .react_jsx_no_undef = false,
        .react_no_array_index_key = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_array_index_key.id));
}
