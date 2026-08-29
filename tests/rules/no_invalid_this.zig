const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const base_options = lint.Options{
    .no_invalid_this = true,
    .no_undef = false,
    .no_unused_vars = false,
    .parser_semantic_errors = false,
};

test "reports module top-level and strict default function bindings" {
    const source =
        \\this.value;
        \\(() => this.value)();
        \\function plain() { this.value; () => this.value; }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", base_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_invalid_this.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_invalid_this.id)) {
            try std.testing.expectEqualStrings("Unexpected 'this'.", diagnostic.message);
        }
    }
}

test "allows script top-level and non-strict functions" {
    const source =
        \\this.value;
        \\(() => this.value)();
        \\function plain() { this.value; () => this.value; }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", base_options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_invalid_this.id));
}

test "recognizes constructors properties explicit binding and callback thisArg" {
    const source =
        \\function Constructor() { this.value; }
        \\const Assigned = function () { this.value; };
        \\const object = { method: function () { this.value; }, shorthand() { this.value; } };
        \\object.assigned = function () { this.value; };
        \\(function () { this.value; }).call(object);
        \\const bound = function () { this.value; }.bind(object);
        \\Reflect.apply(function () { this.value; }, object, []);
        \\Array.from([], function () { this.value; }, object);
        \\items.forEach(function () { this.value; }, object);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", base_options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_invalid_this.id));
}

test "reports nullish explicit bindings and supports capIsConstructor false" {
    const source =
        \\function Constructor() { this.value; }
        \\const Assigned = function () { this.value; };
        \\(function () { this.value; }).call(undefined);
        \\const bound = function () { this.value; }.bind(null);
        \\items.map(function () { this.value; }, void 0);
        \\const dynamic = function () { this.value; }[binding](object);
    ;

    var options = base_options;
    options.no_invalid_this_cap_is_constructor = .no;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.no_invalid_this.id));
}

test "follows IIFE return destinations" {
    const source =
        \\const object = {
        \\  method: (function () { return function () { this.value; }; })(),
        \\  arrowFactory: (() => function () { this.value; })(),
        \\};
        \\target.method = (function () { return function () { this.value; }; })?.();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", base_options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_invalid_this.id));
}

test "handles class fields static blocks and computed keys" {
    const source =
        \\class Example {
        \\  [this.key] = 1;
        \\  field = this.value;
        \\  arrow = () => this.value;
        \\  functionField = function () { this.value; };
        \\  method() { this.value; }
        \\  static { this.value; () => this.value; function nested() { this.value; } }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", base_options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_invalid_this.id));
}

test "supports TypeScript this parameters and JSDoc this tags" {
    const source =
        \\function typed(this: Context) { this.value; }
        \\callback(function (this: Context) { this.value; });
        \\/** @this Context */ function documented() { this.value; }
        \\callback(/* @this Context */ function () { this.value; });
        \\function factory() { /** @this Context */ return function inner() { this.value; }; }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", base_options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_invalid_this.id));
}

test "can disable no-invalid-this" {
    var result = try lint.lintSource(std.testing.allocator, "this.value", "fixture.js", .{
        .no_invalid_this = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_invalid_this.id));
}
