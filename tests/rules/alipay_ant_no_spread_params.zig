const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_no_spread_params = true;
    return options;
}

test "reports @alipay/ant/no-spread-params for JSX spread function params" {
    const source =
        \\function App(props) {
        \\  return <View {...props} />;
        \\}
        \\const Nested = (props) => {
        \\  return function Child() {
        \\    return <View {...props} />;
        \\  };
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_ant_no_spread_params.id));
    try std.testing.expectEqualStrings(
        "不要简单的使用类似`...props`的方式在组件中相互传值, 会造成代码维护/CR难度增大",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "does not report @alipay/ant/no-spread-params for non-param spreads" {
    const source =
        \\const moduleProps = {};
        \\function App(props) {
        \\  const localProps = props;
        \\  return (
        \\    <>
        \\      <View {...localProps} />
        \\      <View {...moduleProps} />
        \\      <View {...props.value} />
        \\    </>
        \\  );
        \\}
        \\function Rest({ value, ...rest }) {
        \\  return <View {...rest} />;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_spread_params.id));
}

test "can disable @alipay/ant/no-spread-params" {
    const source =
        \\function App(props) {
        \\  return <View {...props} />;
        \\}
    ;

    var options = optionsOnly();
    options.alipay_ant_no_spread_params = false;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_spread_params.id));
}
