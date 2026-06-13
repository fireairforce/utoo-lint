const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_jsx_handler_names = true;
    return options;
}

test "reports @alipay/ant/jsx-handler-names for badly named event handlers" {
    const source =
        \\const view = (
        \\  <View
        \\    onClick={foo}
        \\    handleTap={this.nope}
        \\    onPress={props.bad}
        \\    onSubmit={handleSubmit}
        \\    onReady={onReady}
        \\    onLoad={this.handleLoad}
        \\    onFocus={props.onFocus}
        \\    onInline={() => ok()}
        \\    ref={badRef}
        \\  />
        \\);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.alipay_ant_jsx_handler_names.id));
    try std.testing.expectEqualStrings(
        "Handler function for onClick prop key must be a camelCase name beginning with '(on|handle)' only",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqualStrings(
        "Handler function for handleTap prop key must be a camelCase name beginning with '(on|handle)' only",
        result.diagnostics[1].message,
    );
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "allows @alipay/ant/jsx-handler-names valid handler prefixes and qualified names" {
    const source =
        \\const view = (
        \\  <View
        \\    onClick={handleClick}
        \\    onTap={onTap}
        \\    handlePress={actions.handlePress}
        \\    onReady={this.props.onReady}
        \\    on2Ready={handle2Ready}
        \\  />
        \\);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_jsx_handler_names.id));
}

test "can disable @alipay/ant/jsx-handler-names" {
    const source = "const view = <View onClick={foo} />;\n";
    var options = optionsOnly();
    options.alipay_ant_jsx_handler_names = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_jsx_handler_names.id));
}
