const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-is-mounted inside class and object methods" {
    const source =
        \\class Component {
        \\  render() {
        \\    return this.isMounted();
        \\  }
        \\}
        \\const objectComponent = {
        \\  render() {
        \\    return this.isMounted();
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_no_is_mounted.id));
    try std.testing.expectEqualStrings("Do not use isMounted", result.diagnostics[0].message);
}

test "ignores isMounted outside methods and non-this calls" {
    const source =
        \\function check() {
        \\  this.isMounted();
        \\  component.isMounted();
        \\  this["isMounted"]();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_is_mounted.id));
}

test "can disable react/no-is-mounted" {
    const source =
        \\class Component {
        \\  render() {
        \\    return this.isMounted();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .react_no_is_mounted = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_is_mounted.id));
}
