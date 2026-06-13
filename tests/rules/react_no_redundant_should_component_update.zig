const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-redundant-should-component-update for PureComponent classes" {
    const source =
        \\class One extends React.PureComponent {
        \\  shouldComponentUpdate() {
        \\    return true;
        \\  }
        \\}
        \\class Two extends PureComponent {
        \\  shouldComponentUpdate = () => true;
        \\}
        \\const Three = class extends React.PureComponent {
        \\  shouldComponentUpdate() {
        \\    return true;
        \\  }
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_redundant_should_component_update.id));
    try std.testing.expect(hasMessage(result, "One does not need shouldComponentUpdate when extending React.PureComponent."));
    try std.testing.expect(hasMessage(result, "Two does not need shouldComponentUpdate when extending React.PureComponent."));
    try std.testing.expect(hasMessage(result, "Three does not need shouldComponentUpdate when extending React.PureComponent."));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.@"error", diagnostic.severity);
}

test "allows react/no-redundant-should-component-update when not extending PureComponent" {
    const source =
        \\class One extends React.Component {
        \\  shouldComponentUpdate() {
        \\    return true;
        \\  }
        \\}
        \\class Two extends React.PureComponent {
        \\  render() {
        \\    return null;
        \\  }
        \\}
        \\class Three extends React.PureComponent {
        \\  ["shouldComponentUpdate"]() {
        \\    return true;
        \\  }
        \\}
        \\class Four extends React.PureComponent {
        \\  "shouldComponentUpdate"() {
        \\    return true;
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

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_redundant_should_component_update.id));
}

test "can disable react/no-redundant-should-component-update" {
    const source =
        \\class One extends React.PureComponent {
        \\  shouldComponentUpdate() {
        \\    return true;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_no_redundant_should_component_update = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_redundant_should_component_update.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.react_no_redundant_should_component_update.id)) return diagnostic;
    }
    return null;
}

fn hasMessage(result: lint.Result, message: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, message)) return true;
    }
    return false;
}
