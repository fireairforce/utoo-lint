const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-access-state-in-setstate for this.state in setState arguments" {
    const source =
        \\class View extends React.Component {
        \\  update() {
        \\    this.setState({ count: this.state.count + 1 });
        \\    this.setState(() => ({ label: this.state.label }));
        \\    this.setState({ next: update() });
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

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_no_access_state_in_setstate.id));
    try std.testing.expect(hasMessage(result, "Use callback in setState when referencing the previous state."));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.@"error", diagnostic.severity);
}

test "reports react/no-access-state-in-setstate for variables derived from state" {
    const source =
        \\class View extends React.Component {
        \\  update() {
        \\    const count = this.state.count;
        \\    const label = this.state.label;
        \\    this.setState({ count: count });
        \\    this.setState({ label });
        \\  }
        \\}
        \\class Other extends React.Component {
        \\  update = () => {
        \\    const enabled = this.state.enabled;
        \\    this.setState({ enabled });
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

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_access_state_in_setstate.id));
}

test "reports react/no-access-state-in-setstate for destructured state" {
    const source =
        \\class View extends React.Component {
        \\  update() {
        \\    const { state } = this;
        \\    this.setState({ count: state.count });
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

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_no_access_state_in_setstate.id));
}

test "matches react/no-access-state-in-setstate helper call behavior" {
    const source =
        \\class View extends React.Component {
        \\  value() {
        \\    return this.state.count;
        \\  }
        \\  update() {
        \\    this.setState({ ok: this.value() });
        \\    this.setState({ count: value() });
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

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_no_access_state_in_setstate.id));
}

test "allows react/no-access-state-in-setstate outside previous state access" {
    const source =
        \\class View extends React.Component {
        \\  update(nextCount) {
        \\    this.setState((state) => ({ count: state.count + 1 }));
        \\    this.setState({ count: nextCount });
        \\  }
        \\}
        \\class Plain {
        \\  update() {
        \\    this.setState({ count: this.state.count + 1 });
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

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_access_state_in_setstate.id));
}

test "can disable react/no-access-state-in-setstate" {
    const source =
        \\class View extends React.Component {
        \\  update() {
        \\    this.setState({ count: this.state.count + 1 });
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_no_access_state_in_setstate = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_access_state_in_setstate.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.react_no_access_state_in_setstate.id)) return diagnostic;
    }
    return null;
}

fn hasMessage(result: lint.Result, expected: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, expected)) return true;
    }
    return false;
}
