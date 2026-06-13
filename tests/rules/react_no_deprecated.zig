const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-deprecated for deprecated member chains" {
    const source =
        \\React.render(App, root);
        \\ReactDOM.render(<App />, root);
        \\React.PropTypes.component;
        \\this.transferPropsTo(props);
        \\ReactDOMServer.renderToNodeStream(<App />);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.react_no_deprecated.id));
    try std.testing.expect(hasMessage(result, "React.render is deprecated since React 0.14.0, use ReactDOM.render instead"));
    try std.testing.expect(hasMessage(result, "ReactDOM.render is deprecated since React 18.0.0, use createRoot instead, see https://reactjs.org/link/switch-to-createroot"));
    try std.testing.expect(hasMessage(result, "React.PropTypes.component is deprecated since React 0.12.0, use React.PropTypes.element instead"));
    try std.testing.expect(hasMessage(result, "React.PropTypes is deprecated since React 15.5.0, use the npm module prop-types instead"));
    try std.testing.expect(hasMessage(result, "this.transferPropsTo is deprecated since React 0.12.0, use spread operator ({...}) instead"));
    try std.testing.expect(hasMessage(result, "ReactDOMServer.renderToNodeStream is deprecated since React 18.0.0, use renderToPipeableStream instead, see https://reactjs.org/docs/react-dom-server.html#rendertonodestream"));
}

test "reports react/no-deprecated for imports and destructuring" {
    const source =
        \\import { render } from "react-dom";
        \\import { PropTypes } from "react";
        \\const { renderToNodeStream } = ReactDOMServer;
        \\const { render: renderDom } = ReactDOM;
        \\const { render: requireRender } = require("react-dom");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.react_no_deprecated.id));
    try std.testing.expectEqual(@as(usize, 3), countMessage(result, "ReactDOM.render is deprecated since React 18.0.0, use createRoot instead, see https://reactjs.org/link/switch-to-createroot"));
    try std.testing.expect(hasMessage(result, "React.PropTypes is deprecated since React 15.5.0, use the npm module prop-types instead"));
    try std.testing.expect(hasMessage(result, "ReactDOMServer.renderToNodeStream is deprecated since React 18.0.0, use renderToPipeableStream instead, see https://reactjs.org/docs/react-dom-server.html#rendertonodestream"));
}

test "reports react/no-deprecated for component lifecycle methods" {
    const source =
        \\class View extends React.Component {
        \\  componentWillMount() {}
        \\  componentWillReceiveProps() {}
        \\}
        \\
        \\React.createClass({
        \\  componentWillUpdate() {}
        \\});
        \\
        \\createReactClass({
        \\  componentWillUpdate() {}
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.react_no_deprecated.id));
    try std.testing.expect(hasMessage(result, "React.createClass is deprecated since React 15.5.0, use the npm module create-react-class instead"));
    try std.testing.expect(hasMessage(result, "componentWillMount is deprecated since React 16.9.0, use UNSAFE_componentWillMount instead, see https://reactjs.org/docs/react-component.html#unsafe_componentwillmount. Use https://github.com/reactjs/react-codemod#rename-unsafe-lifecycles to automatically update your components."));
    try std.testing.expect(hasMessage(result, "componentWillReceiveProps is deprecated since React 16.9.0, use UNSAFE_componentWillReceiveProps instead, see https://reactjs.org/docs/react-component.html#unsafe_componentwillreceiveprops. Use https://github.com/reactjs/react-codemod#rename-unsafe-lifecycles to automatically update your components."));
    try std.testing.expect(hasMessage(result, "componentWillUpdate is deprecated since React 16.9.0, use UNSAFE_componentWillUpdate instead, see https://reactjs.org/docs/react-component.html#unsafe_componentwillupdate. Use https://github.com/reactjs/react-codemod#rename-unsafe-lifecycles to automatically update your components."));
}

test "allows react/no-deprecated for non-components and current APIs" {
    const source =
        \\class Plain {
        \\  componentWillMount() {}
        \\}
        \\const spec = {
        \\  componentWillUpdate() {}
        \\};
        \\ReactDOM.createRoot(root);
        \\ReactDOMServer.renderToPipeableStream(<App />);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_deprecated.id));
}

test "can disable react/no-deprecated" {
    const source =
        \\ReactDOM.render(<App />, root);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_no_deprecated = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_deprecated.id));
}

fn hasMessage(result: lint.Result, message: []const u8) bool {
    return countMessage(result, message) > 0;
}

fn countMessage(result: lint.Result, message: []const u8) usize {
    var count: usize = 0;
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.react_no_deprecated.id) and
            std.mem.eql(u8, diagnostic.message, message))
        {
            count += 1;
        }
    }
    return count;
}
