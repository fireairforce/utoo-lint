const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports func-names for unnamed function expressions" {
    const source =
        \\const first = function () {
        \\  return value;
        \\};
        \\const object = {
        \\  method: function () {
        \\    return value;
        \\  },
        \\};
        \\const generator = function* () {
        \\  yield value;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.func_names.id));
    try std.testing.expectEqualStrings("Unexpected unnamed function.", result.diagnostics[0].message);
}

test "reports func-names for unnamed default-exported functions" {
    const source =
        \\export default function () {
        \\  return value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.func_names.id));
}

test "allows named functions and non-function-expression callbacks" {
    const source =
        \\function declaration() {
        \\  return value;
        \\}
        \\export default function namedDefault() {
        \\  return value;
        \\}
        \\const first = function namedExpression() {
        \\  return value;
        \\};
        \\const object = {
        \\  method() {
        \\    return value;
        \\  },
        \\};
        \\const arrow = () => value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.func_names.id));
}

test "allows func-names as-needed for inferable names" {
    const source =
        \\const first = function () {
        \\  return value;
        \\};
        \\const object = {
        \\  method: function () {
        \\    return value;
        \\  },
        \\};
        \\class Example {
        \\  field = function () {
        \\    return value;
        \\  };
        \\}
        \\quux ??= function () {
        \\  return value;
        \\};
        \\const { local = function () {
        \\  return value;
        \\} } = object;
        \\const [item = function () {
        \\  return value;
        \\}] = array;
        \\({ assigned = function () {
        \\  return value;
        \\} } = object);
        \\[assignedItem = function () {
        \\  return value;
        \\}] = array;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .func_names_style = .as_needed,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.func_names.id));
}

test "reports func-names as-needed for non-inferable names" {
    const source =
        \\const call = (function () {
        \\  return value;
        \\})();
        \\Foo.prototype.bar = function () {
        \\  return value;
        \\};
        \\export default function () {
        \\  return value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .func_names_style = .as_needed,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.func_names.id));
}

test "reports func-names never for named function expressions" {
    const source =
        \\const first = function namedExpression() {
        \\  return value;
        \\};
        \\const object = {
        \\  property: function namedProperty() {
        \\    return value;
        \\  },
        \\};
        \\const generator = function* namedGenerator() {
        \\  yield value;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .func_name_matching = false,
        .func_names_style = .never,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.func_names.id));
    try std.testing.expectEqualStrings("Unexpected named function.", result.diagnostics[0].message);
}

test "allows func-names never for anonymous expressions and declarations" {
    const source =
        \\function declaration() {
        \\  return value;
        \\}
        \\export default function namedDefault() {
        \\  return value;
        \\}
        \\const first = function () {
        \\  return value;
        \\};
        \\const object = {
        \\  method() {
        \\    return value;
        \\  },
        \\};
        \\const arrow = () => value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .func_name_matching = false,
        .func_names_style = .never,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.func_names.id));
}

test "can disable func-names" {
    const source = "const value = function () { return 1; };\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .func_names = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.func_names.id));
}
