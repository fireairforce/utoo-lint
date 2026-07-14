const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-object-has-own for hasOwnProperty call helpers" {
    const source =
        \\Object.prototype.hasOwnProperty.call(object, "key");
        \\Object.hasOwnProperty.call(object, "key");
        \\({}).hasOwnProperty.call(object, "key");
        \\Object["prototype"]["hasOwnProperty"]["call"](object, "key");
        \\Object[`prototype`][`hasOwnProperty`][`call`](object, "key");
        \\Object.prototype.hasOwnProperty.call?.(object, "key");
        \\Object.prototype.hasOwnProperty?.call(object, "key");
        \\Object?.prototype.hasOwnProperty.call(object, "key");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 8), helpers.countRule(result, lint.rules.prefer_object_has_own.id));
    try std.testing.expectEqualStrings(
        "Use 'Object.hasOwn()' instead of 'Object.prototype.hasOwnProperty.call()'.",
        result.diagnostics[0].message,
    );
}

test "does not report prefer-object-has-own for other calls or shadowed Object" {
    const source =
        \\Object.hasOwn(object, "key");
        \\Object.prototype.propertyIsEnumerable.call(object, "key");
        \\object.hasOwnProperty("key");
        \\Object.prototype.hasOwnProperty.apply(object, ["key"]);
        \\Object[`proto${suffix}`][`hasOwnProperty`][`call`](object, "key");
        \\function local(Object) {
        \\  Object.prototype.hasOwnProperty.call(object, "key");
        \\  Object.hasOwnProperty.call(object, "key");
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_prototype_builtins = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_object_has_own.id));
}

test "autofixes hasOwnProperty call helpers to Object.hasOwn" {
    const source =
        \\Object.prototype.hasOwnProperty.call(object, "key");
        \\Object.hasOwnProperty.call(object, "key");
        \\({}).hasOwnProperty.call(object, "key");
        \\Object["prototype"]["hasOwnProperty"]["call"](object, "key");
        \\Object.prototype.hasOwnProperty.call?.(object, "key");
        \\Object.prototype.hasOwnProperty?.call(object, "key");
        \\Object?.prototype.hasOwnProperty.call(object, "key");
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_prototype_builtins = false,
        .no_undef = false,
        .typescript_eslint_dot_notation = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\Object.hasOwn(object, "key");
        \\Object.hasOwn(object, "key");
        \\Object.hasOwn(object, "key");
        \\Object.hasOwn(object, "key");
        \\Object.hasOwn?.(object, "key");
        \\Object.prototype.hasOwnProperty?.call(object, "key");
        \\Object?.prototype.hasOwnProperty.call(object, "key");
    , result.output);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result.result, lint.rules.prefer_object_has_own.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.prefer_object_has_own.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "autofixes Object.hasOwn safely without dropping comments or matching nonempty objects" {
    const source =
        \\function check() {
        \\  return{}.hasOwnProperty.call(object, "key");
        \\}
        \\Object/* keep */.prototype.hasOwnProperty.call(object, "key");
        \\({ value: 1 }).hasOwnProperty.call(object, "key");
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_prototype_builtins = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\function check() {
        \\  return Object.hasOwn(object, "key");
        \\}
        \\Object/* keep */.prototype.hasOwnProperty.call(object, "key");
        \\({ value: 1 }).hasOwnProperty.call(object, "key");
    , result.output);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result.result, lint.rules.prefer_object_has_own.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.prefer_object_has_own.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "can disable prefer-object-has-own" {
    const source = "Object.prototype.hasOwnProperty.call(object, \"key\");\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .prefer_object_has_own = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_object_has_own.id));
}
