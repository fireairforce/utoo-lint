const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-this-in-sfc for function components" {
    const source =
        \\function Button() {
        \\  return <button>{this.props.label}</button>;
        \\}
        \\
        \\const Link = () => <a>{this.context.url}</a>;
        \\
        \\const Icon = function () {
        \\  return React.createElement('span', null, this.props.name);
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_this_in_sfc.id));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("Stateless functional components should not use `this`", diagnostic.message);
    try std.testing.expectEqual(.@"error", diagnostic.severity);
}

test "allows react/no-this-in-sfc outside stateless function components" {
    const source =
        \\function helper() {
        \\  return this.value;
        \\}
        \\
        \\class Button extends React.Component {
        \\  render() {
        \\    return <button>{this.props.label}</button>;
        \\  }
        \\}
        \\
        \\const lower = () => <span>{this.value}</span>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_this_in_sfc.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.react_no_this_in_sfc.id)) return diagnostic;
    }
    return null;
}

test "can disable react/no-this-in-sfc" {
    const source =
        \\function Button() {
        \\  return <button>{this.props.label}</button>;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
        .react_no_this_in_sfc = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_this_in_sfc.id));
}
