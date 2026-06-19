const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn propTypesOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.react_prop_types = true;
    return options;
}

test "reports react/prop-types for missing function component props" {
    const source =
        \\import React from 'react';
        \\function Foo(props) {
        \\  return <div>{props.name}{props.user.name}</div>;
        \\}
        \\Foo.propTypes = {
        \\  user: PropTypes.shape({
        \\    id: PropTypes.string,
        \\  }),
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", propTypesOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_prop_types.id));
    try std.testing.expect(std.mem.eql(u8, result.diagnostics[0].message, "'name' is missing in props validation"));
    try std.testing.expect(std.mem.eql(u8, result.diagnostics[1].message, "'user.name' is missing in props validation"));
}

test "supports configured react/prop-types skipUndeclared" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"skipUndeclared\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("react/prop-types", config.value);

    const source =
        \\import React from 'react';
        \\function Foo(props) {
        \\  return <div>{props.name}</div>;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_prop_types.id));
}

test "supports configured react/prop-types ignore" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignore\":[\"name\",\"user\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("react/prop-types", config.value);

    const source =
        \\import React from 'react';
        \\function Foo(props) {
        \\  return <div>{props.name}{props.user.name}{props.age}</div>;
        \\}
        \\Foo.propTypes = {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_prop_types.id));
    var saw_age = false;
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.react_prop_types.id)) {
            saw_age = std.mem.eql(u8, diagnostic.message, "'age' is missing in props validation");
        }
    }
    try std.testing.expect(saw_age);
}

test "allows react/prop-types declared object children" {
    const source =
        \\import React from 'react';
        \\function Foo(props) {
        \\  return <div>{props.user.name}</div>;
        \\}
        \\Foo.propTypes = {
        \\  user: PropTypes.object,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", propTypesOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_prop_types.id));
}

test "reports react/prop-types for destructured parameters" {
    const source =
        \\import React from 'react';
        \\function Foo({ name, user: { id } }) {
        \\  return <div>{name}{id}</div>;
        \\}
        \\Foo.propTypes = {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", propTypesOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_prop_types.id));
    try std.testing.expect(std.mem.eql(u8, result.diagnostics[0].message, "'name' is missing in props validation"));
    try std.testing.expect(std.mem.eql(u8, result.diagnostics[1].message, "'user' is missing in props validation"));
    try std.testing.expect(std.mem.eql(u8, result.diagnostics[2].message, "'user.id' is missing in props validation"));
}

test "reports react/prop-types for class components" {
    const source =
        \\import React from 'react';
        \\class Foo extends React.Component {
        \\  render() {
        \\    return <div>{this.props.name}</div>;
        \\  }
        \\}
        \\Foo.propTypes = {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", propTypesOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_prop_types.id));
    try std.testing.expect(std.mem.eql(u8, result.diagnostics[0].message, "'name' is missing in props validation"));
}

test "does not treat uppercase non components as react/prop-types components" {
    const source =
        \\function Foo(props) {
        \\  return props.name;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", propTypesOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_prop_types.id));
}

test "can disable react/prop-types" {
    const source =
        \\import React from 'react';
        \\function Foo(props) {
        \\  return <div>{props.name}</div>;
        \\}
    ;

    var options = propTypesOnly();
    options.react_prop_types = false;
    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_prop_types.id));
}
