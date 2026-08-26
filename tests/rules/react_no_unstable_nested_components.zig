const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.react_no_unstable_nested_components.id;

test "reports nested function declarations, expressions, arrows, and wrappers" {
    const source =
        \\function Parent() {
        \\  function Decl() { return <div />; }
        \\  const Expr = function Expr() { return <span />; };
        \\  const Arrow = () => <section />;
        \\  const Wrapped = memo(() => <article />);
        \\  return <Wrapped />;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, rule_id));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
}

test "allows module components and ordinary nested helpers and callbacks" {
    const source =
        \\const ModuleArrow = () => <div />;
        \\function ModuleDeclaration() { return <div />; }
        \\function Parent({ items }) {
        \\  const helper = () => <span />;
        \\  const rows = items.map(() => <ModuleArrow />);
        \\  function callback(value) { return value + 1; }
        \\  callback(rows.length);
        \\  return <main>{rows}{helper()}</main>;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, rule_id));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
}

test "supports render props, custom prop patterns, and allowAsProps" {
    const source =
        \\function Parent() {
        \\  const props = {
        \\    renderItem: () => <div />,
        \\    slotHeader: () => <header />,
        \\    footer: () => <footer />,
        \\  };
        \\  return <Panel {...props} />;
        \\}
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", ruleOptions());
    defer default_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(default_result, rule_id));

    var custom_options = ruleOptions();
    try std.testing.expect(custom_options.react_no_unstable_nested_components_prop_name_pattern.set("slot*"));
    var custom_result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", custom_options);
    defer custom_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(custom_result, rule_id));

    var allow_options = ruleOptions();
    allow_options.react_no_unstable_nested_components_allow_as_props = true;
    var allow_result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", allow_options);
    defer allow_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(allow_result, rule_id));
}

test "supports JSX render props and children compatibility" {
    const source =
        \\function Parent() {
        \\  return (
        \\    <Panel
        \\      renderItem={() => <div />}
        \\      footer={() => <footer />}
        \\    >
        \\      {() => <span />}
        \\    </Panel>
        \\  );
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
}

test "reports nested components in React class render methods" {
    const source =
        \\class Parent extends React.Component {
        \\  render() {
        \\    const Child = () => <div />;
        \\    return <Child />;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
}

test "accepts CLI and upstream-compatible rule configuration" {
    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.react_no_unstable_nested_components);

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"warn\",{\"allowAsProps\":true,\"propNamePattern\":\"slot*\",\"customValidators\":[\"shape\"]}]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue(rule_id, config.value);

    try std.testing.expect(options.react_no_unstable_nested_components_allow_as_props);
    try std.testing.expectEqualStrings("slot*", options.react_no_unstable_nested_components_prop_name_pattern.pattern());
}

test "parses JS TS JSX and TSX fixtures without parser diagnostics" {
    const Fixture = struct {
        path: []const u8,
        source: []const u8,
    };
    const fixtures = [_]Fixture{
        .{
            .path = "fixture.js",
            .source =
            \\function Parent() {
            \\  function Decl() { return React.createElement("div"); }
            \\  const Expr = function Expr() { return React.createElement("span"); };
            \\  const Arrow = () => React.createElement("article");
            \\  return React.createElement(Arrow);
            \\}
            ,
        },
        .{
            .path = "fixture.jsx",
            .source =
            \\function Parent() {
            \\  function Decl() { return <div />; }
            \\  const Expr = function Expr() { return <span />; };
            \\  const Arrow = () => <article />;
            \\  return <Arrow />;
            \\}
            ,
        },
        .{
            .path = "fixture.ts",
            .source =
            \\function Parent(): unknown {
            \\  function Decl(): unknown { return React.createElement("div"); }
            \\  const Expr = function Expr(): unknown { return React.createElement("span"); };
            \\  const Arrow = (): unknown => React.createElement("article");
            \\  return React.createElement(Arrow);
            \\}
            ,
        },
        .{
            .path = "fixture.tsx",
            .source =
            \\function Parent<T extends object>(props: T) {
            \\  function Decl(): JSX.Element { return <div data-props={props} />; }
            \\  const Expr = function Expr(): JSX.Element { return <span />; };
            \\  const Arrow = (): JSX.Element => <article />;
            \\  return <Arrow />;
            \\}
            ,
        },
    };

    for (fixtures) |fixture| {
        var result = try lint.lintSource(std.testing.allocator, fixture.source, fixture.path, ruleOptions());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
        try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, rule_id));
    }
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.react_no_unstable_nested_components = true;
    return options;
}
