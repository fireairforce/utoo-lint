const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-multi-comp for multiple non stateless components" {
    const source =
        \\class One extends React.Component {
        \\  render() {
        \\    return null;
        \\  }
        \\}
        \\class Two extends React.PureComponent {
        \\  render() {
        \\    return null;
        \\  }
        \\}
        \\class Three extends Component {
        \\  render() {
        \\    return null;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_no_multi_comp.id));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.@"error", diagnostic.severity);
    try std.testing.expectEqualStrings("Declare only one React component per file", diagnostic.message);
}

test "allows react/no-multi-comp ignored stateless and single class components" {
    const source =
        \\class One extends React.Component {
        \\  render() {
        \\    return null;
        \\  }
        \\}
        \\function Two() {
        \\  return <div />;
        \\}
        \\const Three = () => <span />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_multi_comp.id));
}

test "can disable react/no-multi-comp" {
    const source =
        \\class One extends React.Component {
        \\  render() {
        \\    return null;
        \\  }
        \\}
        \\class Two extends React.Component {
        \\  render() {
        \\    return null;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_no_multi_comp = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_multi_comp.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.react_no_multi_comp.id)) return diagnostic;
    }
    return null;
}
