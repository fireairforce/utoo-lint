const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const test_options = lint.Options{
    .no_undef = false,
    .no_unused_vars = false,
    .typescript_eslint_no_unused_vars = false,
    .react_jsx_no_undef = false,
};

test "reports JSX elements without keys in arrays" {
    const source =
        \\const nodes = [
        \\  <Item />,
        \\  <Item key="stable" />,
        \\  <Item {...props} />,
        \\];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_jsx_key.id));
}

test "reports JSX elements without keys in map callbacks" {
    const source =
        \\items.map((item) => <Item value={item} />);
        \\items.map((item) => condition ? <Item value={item} /> : <Other key={item.id} />);
        \\items.map((item) => condition && <Item value={item} />);
        \\items.map((item) => <Item key={item.id} value={item} />);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_jsx_key.id));
}

test "supports configured react jsx key must appear before spread" {
    const source =
        \\const nodes = [
        \\  <Item key="stable" {...props} />,
        \\  <Item {...props} key="late" />,
        \\];
        \\items.map((item) => <Item {...item} key={item.id} />);
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"checkKeyMustBeforeSpread\":true}]",
        .{},
    );
    defer config.deinit();

    var options = test_options;
    try options.setByRuleConfigValue("react/jsx-key", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_jsx_key.id));
}

test "supports configured react jsx key fragment shorthand" {
    const source =
        \\const nodes = [
        \\  <></>,
        \\  <Item key="stable" />,
        \\];
        \\items.map((item) => <>{item.name}</>);
        \\items.map((item) => <Item key={item.id} />);
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"checkFragmentShorthand\":true}]",
        .{},
    );
    defer config.deinit();

    var options = test_options;
    try options.setByRuleConfigValue("react/jsx-key", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_jsx_key.id));
}

test "allows react jsx key fragment shorthand by default" {
    const source =
        \\const nodes = [
        \\  <></>,
        \\];
        \\items.map((item) => <>{item.name}</>);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_key.id));
}

test "reports JSX elements without keys in block callback returns" {
    const source =
        \\items.map(function (item) {
        \\  if (item.visible) {
        \\    return <Item value={item} />;
        \\  }
        \\  return <Fallback key={item.id} />;
        \\});
        \\items.map((item) => {
        \\  if (item.ready) return <Ready value={item} />;
        \\  return null;
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_jsx_key.id));
}

test "reports Array.from mapper results and ignores Children.toArray" {
    const source =
        \\Array.from(items, (item) => <Item value={item} />);
        \\React.Children.toArray([<Item />, <Item />]);
        \\Children.toArray(items.map((item) => <Item value={item} />));
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_key.id));
}

test "can disable react jsx key" {
    const source = "const nodes = [<Item />];";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .react_jsx_no_undef = false,
        .react_jsx_key = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_key.id));
}
