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

test "supports configured no-underscore-dangle options" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowAfterThis\":true,\"allowAfterSuper\":true,\"allowAfterThisConstructor\":true,\"allowFunctionParams\":false,\"allowInArrayDestructuring\":false,\"allowInObjectDestructuring\":false,\"enforceInMethodNames\":true,\"enforceInClassFields\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-underscore-dangle", config.value);
    options.no_empty_function = false;
    options.no_undef = false;
    options.no_unused_expressions = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\class Child extends Parent {
        \\  _run() {}
        \\  _field = 1;
        \\  method() {
        \\    this._allowed;
        \\    super._allowed;
        \\    this.constructor._allowed;
        \\    object._member;
        \\  }
        \\}
        \\function run(_param) {
        \\  return _param;
        \\}
        \\const [_array] = values;
        \\const { _object } = record;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.no_underscore_dangle.id));
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

test "reports no-underscore-dangle for destructuring when configured" {
    const source =
        \\const [_array, value_, ..._rest] = values;
        \\const { _object, nested: { child_ }, _alias: alias } = record;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_underscore_dangle_allow_in_array_destructuring = .no,
        .no_underscore_dangle_allow_in_object_destructuring = .no,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_underscore_dangle.id));
}

test "reports no-underscore-dangle for method names when configured" {
    const source =
        \\class Model {
        \\  _run() {}
        \\  #private_() {}
        \\}
        \\const object = {
        \\  _run() {},
        \\  get value_() {
        \\    return 1;
        \\  },
        \\  _field: 1,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_underscore_dangle_enforce_in_method_names = true,
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_underscore_dangle.id));
}

test "reports no-underscore-dangle for class fields when configured" {
    const source =
        \\class Model {
        \\  _field = 1;
        \\  #private_ = 2;
        \\  static value_ = 3;
        \\  ["_computed"] = 4;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_underscore_dangle_enforce_in_class_fields = true,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_underscore_dangle.id));
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
