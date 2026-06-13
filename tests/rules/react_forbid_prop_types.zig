const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/forbid-prop-types for forbidden direct prop types" {
    const source =
        \\class View extends React.Component {
        \\  static propTypes = {
        \\    anyValue: PropTypes.any,
        \\    arrayValue: PropTypes.array.isRequired,
        \\    objectValue: PropTypes.object,
        \\    stringValue: PropTypes.string,
        \\  };
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_forbid_prop_types.id));
    try std.testing.expect(hasMessage(result, "Prop type \"any\" is forbidden"));
    try std.testing.expect(hasMessage(result, "Prop type \"array\" is forbidden"));
    try std.testing.expect(hasMessage(result, "Prop type \"object\" is forbidden"));
}

test "reports react/forbid-prop-types in assignments and variable references" {
    const source =
        \\const declaredTypes = {
        \\  anyValue: PropTypes.any,
        \\  stringValue: PropTypes.string,
        \\};
        \\View.propTypes = declaredTypes;
        \\Other.propTypes = {
        \\  arrayValue: PropTypes.array,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_forbid_prop_types.id));
}

test "reports react/forbid-prop-types in prop type wrappers" {
    const source =
        \\import PropTypes from 'prop-types';
        \\class View extends React.Component {
        \\  static propTypes = {
        \\    shapeValue: PropTypes.shape({
        \\      nested: PropTypes.object,
        \\    }),
        \\    exactValue: PropTypes.exact({
        \\      nested: PropTypes.array,
        \\    }),
        \\    oneOfTypeValue: PropTypes.oneOfType([
        \\      PropTypes.string,
        \\      PropTypes.any,
        \\    ]),
        \\    arrayOfValue: PropTypes.arrayOf(PropTypes.object),
        \\    objectOfValue: PropTypes.objectOf(PropTypes.array),
        \\  };
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_forbid_prop_types.id));
}

test "reports react/forbid-prop-types for object and method declarations" {
    const source =
        \\const View = {
        \\  propTypes: {
        \\    anyValue: PropTypes.any,
        \\  },
        \\};
        \\class Other extends React.Component {
        \\  propTypes() {
        \\    return {
        \\      objectValue: PropTypes.object,
        \\    };
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

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_forbid_prop_types.id));
}

test "allows react/forbid-prop-types for accepted types and foreign PropTypes bindings" {
    const source =
        \\import { PropTypes } from 'other-types';
        \\class View extends React.Component {
        \\  static propTypes = {
        \\    anyValue: PropTypes.any,
        \\    nodeValue: React.PropTypes.node,
        \\  };
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_forbid_prop_types.id));
}

test "can disable react/forbid-prop-types" {
    const source =
        \\class View extends React.Component {
        \\  static propTypes = {
        \\    anyValue: PropTypes.any,
        \\  };
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_forbid_prop_types = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_forbid_prop_types.id));
}

fn hasMessage(result: lint.Result, expected: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, expected)) return true;
    }
    return false;
}
