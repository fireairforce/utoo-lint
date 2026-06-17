const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const test_options = lint.Options{
    .no_undef = false,
    .no_unused_vars = false,
    .typescript_eslint_no_unused_vars = false,
    .react_jsx_no_undef = false,
};

test "reports inline function values in JSX props" {
    const source =
        \\const one = <Button onClick={() => action()} />;
        \\const two = <Button onClick={function () { action(); }} />;
        \\const three = <Button onClick={this.handle.bind(this)} />;
        \\const four = <Button onClick={condition ? () => a() : handler} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.react_jsx_no_bind.id));
}

test "reports const and function aliases from enclosing blocks" {
    const source =
        \\function Demo() {
        \\  const onClick = () => action();
        \\  const onFocus = this.handle.bind(this);
        \\  function onBlur() {}
        \\  return <Button onClick={onClick} onFocus={onFocus} onBlur={onBlur} />;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_jsx_no_bind.id));
}

test "does not report safe prop references" {
    const source =
        \\const handler = () => action();
        \\function Demo(props) {
        \\  const onClick = props.onClick;
        \\  return <Button onClick={onClick} onFocus={handler} />;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_no_bind.id));
}

test "supports configured react/jsx-no-bind allow options" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowArrowFunctions\":true,\"allowFunctions\":true,\"allowBind\":true}]",
        .{},
    );
    defer config.deinit();

    var options = test_options;
    try options.setByRuleConfigValue("react/jsx-no-bind", config.value);

    const source =
        \\function Demo() {
        \\  const alias = () => action();
        \\  function handler() {}
        \\  return (
        \\    <Button
        \\      onClick={() => action()}
        \\      onFocus={function () { action(); }}
        \\      onMouseDown={this.handle.bind(this)}
        \\      onKeyDown={alias}
        \\      onBlur={handler}
        \\    />
        \\  );
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_no_bind.id));
}

test "supports configured react/jsx-no-bind ignore options" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreRefs\":true,\"ignoreDOMComponents\":true}]",
        .{},
    );
    defer config.deinit();

    var options = test_options;
    try options.setByRuleConfigValue("react/jsx-no-bind", config.value);

    const source =
        \\const ignoredRef = <Button ref={() => action()} />;
        \\const ignoredDom = <button onClick={() => action()} />;
        \\const reported = <Button onClick={() => action()} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_no_bind.id));
}

test "can disable react jsx no bind" {
    const source = "const node = <Button onClick={() => action()} />;";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .react_jsx_no_undef = false,
        .react_jsx_no_bind = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_no_bind.id));
}
