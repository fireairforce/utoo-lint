const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports unused state fields declared in class components" {
    const source =
        \\class View extends React.Component {
        \\  state = { classUnused: 1, used: 2 };
        \\  constructor() {
        \\    super();
        \\    this.state = { ctorUnused: 1, title: '' };
        \\  }
        \\  render() {
        \\    return <div>{this.state.title}{this.state.used}</div>;
        \\  }
        \\  update() {
        \\    this.setState({ updateUnused: 1, count: 0 });
        \\  }
        \\  countIt() {
        \\    return this.state.count;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_unused_state.id));
    try std.testing.expect(hasMessage(result, "Unused state field: 'classUnused'"));
    try std.testing.expect(hasMessage(result, "Unused state field: 'ctorUnused'"));
    try std.testing.expect(hasMessage(result, "Unused state field: 'updateUnused'"));
}

test "marks aliases destructuring and lifecycle state parameters as used" {
    const source =
        \\class View extends React.Component {
        \\  state = { a: 1, b: 2, c: 3, d: 4 };
        \\  render() {
        \\    const s = this.state;
        \\    const { b, ...rest } = this.state;
        \\    return <div>{s.a}{b}{rest.c}</div>;
        \\  }
        \\  componentDidUpdate(prevProps, prevState) {
        \\    return prevState.d;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_unused_state.id));
}

test "abandons component analysis for dynamic state usage" {
    const source =
        \\class View extends React.Component {
        \\  state = { unused: 1 };
        \\  render() {
        \\    return <div {...this.state} />;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_unused_state.id));
}

test "reports unused state fields from createReactClass getInitialState" {
    const source =
        \\createReactClass({
        \\  getInitialState() {
        \\    return { used: 1, unused: 2 };
        \\  },
        \\  render() {
        \\    return <div>{this.state.used}</div>;
        \\  },
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_no_unused_state.id));
    try std.testing.expect(hasMessage(result, "Unused state field: 'unused'"));
}

test "can disable react/no-unused-state" {
    const source =
        \\class View extends React.Component {
        \\  state = { unused: 1 };
        \\  render() {
        \\    return <div />;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_jsx_no_undef = false,
        .react_jsx_uses_react = false,
        .react_no_unused_state = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_unused_state.id));
}

fn baseOptions() lint.Options {
    return .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_jsx_no_undef = false,
        .react_jsx_uses_react = false,
        .react_jsx_uses_vars = false,
    };
}

fn hasMessage(result: lint.Result, expected: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.react_no_unused_state.id) and
            std.mem.eql(u8, diagnostic.message, expected))
        {
            return true;
        }
    }
    return false;
}
