const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.react_no_direct_mutation_state.id;

test "reports direct state assignments and updates in React components" {
    const source =
        \\class View extends React.Component {
        \\  update(value) {
        \\    this.state.count = value;
        \\    this.state.person.name = "Ada";
        \\    this.state.count++;
        \\    --this.state.count;
        \\  }
        \\}
        \\class PureView extends PureComponent {
        \\  update() {
        \\    this.state.ready = true;
        \\  }
        \\}
        \\const Legacy = createReactClass({
        \\  render() {
        \\    this.state.visible = true;
        \\    return <div />;
        \\  },
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, rule_id));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.@"error", diagnostic.severity);
    try std.testing.expectEqualStrings("Do not mutate state directly. Use setState().", diagnostic.message);
    try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
}

test "allows constructor initialization and setState but reports constructor callbacks" {
    const source =
        \\class View extends React.Component {
        \\  constructor(props) {
        \\    super(props);
        \\    this.state = { count: 0 };
        \\    this.state.ready = true;
        \\    this.state.count++;
        \\    this.onClick = () => { this.state.clicked = true; };
        \\    consume(this.state.count = 2);
        \\    schedule(() => {
        \\      this.state.count = 1;
        \\    });
        \\  }
        \\  update() {
        \\    this.setState({ count: 2 });
        \\    this.setState((state) => ({ count: state.count + 1 }));
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, rule_id));
}

test "matches upstream alias computed nested and destructured behavior" {
    const source =
        \\class View extends React.Component {
        \\  update(state) {
        \\    const that = this;
        \\    const { state: localState } = this;
        \\    that.state.aliased = true;
        \\    localState.destructured = true;
        \\    this["state"].literal = true;
        \\    this[state].computed = true;
        \\    this.state["person"].name = "Grace";
        \\    (this.state).parenthesized = true;
        \\    this.state = { replaced: true };
        \\  }
        \\}
        \\class Plain {
        \\  update() {
        \\    this.state.value = 1;
        \\  }
        \\}
        \\const Legacy = React.createClass({
        \\  render() {
        \\    const obj = { state: {} };
        \\    obj.state.value = 1;
        \\    return null;
        \\  },
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, rule_id));
}

test "preserves upstream TypeScript non-null assertion behavior" {
    const source =
        \\class View extends React.Component<{}, { count: number }> {
        \\  update(): void {
        \\    this.state!.count = 1;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "accepts CLI and project rule configuration" {
    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.react_no_direct_mutation_state);

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\"]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue(rule_id, config.value);
    try std.testing.expect(options.react_no_direct_mutation_state);
}

test "parses and reports JS TS JSX and TSX fixtures" {
    const Fixture = struct {
        path: []const u8,
        source: []const u8,
    };
    const fixtures = [_]Fixture{
        .{
            .path = "fixture.js",
            .source =
            \\class View extends React.Component {
            \\  update() { this.state.count = 1; }
            \\}
            ,
        },
        .{
            .path = "fixture.jsx",
            .source =
            \\class View extends React.Component {
            \\  update() { this.state.count = 1; }
            \\  render() { return <div />; }
            \\}
            ,
        },
        .{
            .path = "fixture.ts",
            .source =
            \\class View extends React.Component<{}, { count: number }> {
            \\  update(): void { this.state.count = 1; }
            \\}
            ,
        },
        .{
            .path = "fixture.tsx",
            .source =
            \\class View extends React.Component<{}, { count: number }> {
            \\  update(): void { this.state.count = 1; }
            \\  render(): JSX.Element { return <div />; }
            \\}
            ,
        },
    };

    for (fixtures) |fixture| {
        var result = try lint.lintSource(std.testing.allocator, fixture.source, fixture.path, ruleOptions());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "can disable react/no-direct-mutation-state" {
    const source =
        \\class View extends React.Component {
        \\  update() { this.state.count = 1; }
        \\}
    ;

    var options = ruleOptions();
    options.react_no_direct_mutation_state = false;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.react_no_direct_mutation_state = true;
    return options;
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return diagnostic;
    }
    return null;
}
