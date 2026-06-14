const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-underscore-dangle for declarations" {
    const source =
        \\const _value = 1;
        \\let value_ = 2;
        \\function _run() {}
        \\class Model_ {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_underscore_dangle.id));
}

test "reports no-underscore-dangle for member properties" {
    const source =
        \\object._value;
        \\object.value_;
        \\this._value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_underscore_dangle.id));
}

test "reports no-underscore-dangle for configured member contexts by default" {
    const source =
        \\class Child extends Parent {
        \\  method() {
        \\    this._value;
        \\    super._value;
        \\    this.constructor._value;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_underscore_dangle.id));
}

test "allows no-underscore-dangle configured member contexts" {
    const source =
        \\class Child extends Parent {
        \\  method() {
        \\    this._value;
        \\    super._value;
        \\    this.constructor._value;
        \\    object._value;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_underscore_dangle_allow_after_this = true,
        .no_underscore_dangle_allow_after_super = true,
        .no_underscore_dangle_allow_after_this_constructor = true,
        .no_undef = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_underscore_dangle.id));
}

test "allows default names and skipped forms" {
    const source =
        \\const _ = 1;
        \\const __filename = "file";
        \\const __dirname = "dir";
        \\const { _value } = object;
        \\function run(_param) {}
        \\object.__proto__;
        \\object["_value"];
        \\const record = { _value: 1, method_() {} };
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_underscore_dangle.id));
}

test "reports no-underscore-dangle for function params when configured" {
    const source =
        \\function run(_value, value_, _default = 1, ..._rest) {}
        \\const arrow = ({ _object }, [_item]) => _object + _item;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_underscore_dangle_allow_function_params = .no,
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.no_underscore_dangle.id));
}

test "can disable no-underscore-dangle" {
    const source =
        \\const _value = 1;
        \\object._value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_underscore_dangle = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_underscore_dangle.id));
}
