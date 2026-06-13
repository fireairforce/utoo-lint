const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-will-update-set-state in componentWillUpdate lifecycles" {
    const source =
        \\class One extends React.Component {
        \\  componentWillUpdate() {
        \\    this.setState({ value: 1 });
        \\  }
        \\}
        \\class Two extends React.Component {
        \\  UNSAFE_componentWillUpdate() {
        \\    this.setState({ value: 2 });
        \\  }
        \\}
        \\const spec = {
        \\  componentWillUpdate() {
        \\    this.setState({ value: 3 });
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_will_update_set_state.id));
    try std.testing.expect(hasMessage(result, "Do not use setState in componentWillUpdate"));
    try std.testing.expect(hasMessage(result, "Do not use setState in UNSAFE_componentWillUpdate"));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.@"error", diagnostic.severity);
}

test "allows react/no-will-update-set-state outside checked lifecycle contexts" {
    const source =
        \\class One extends React.Component {
        \\  componentDidUpdate() {
        \\    this.setState({ value: 1 });
        \\  }
        \\  componentWillUpdate() {
        \\    function later() {
        \\      this.setState({ value: 2 });
        \\    }
        \\  }
        \\  ["componentWillUpdate"]() {
        \\    this.setState({ value: 3 });
        \\  }
        \\}
        \\const spec = {
        \\  componentWillUpdate: function () {
        \\    function later() {
        \\      this.setState({ value: 4 });
        \\    }
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_will_update_set_state.id));
}

test "can disable react/no-will-update-set-state" {
    const source =
        \\class One extends React.Component {
        \\  componentWillUpdate() {
        \\    this.setState({ value: 1 });
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_no_will_update_set_state = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_will_update_set_state.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.react_no_will_update_set_state.id)) return diagnostic;
    }
    return null;
}

fn hasMessage(result: lint.Result, message: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, message)) return true;
    }
    return false;
}
