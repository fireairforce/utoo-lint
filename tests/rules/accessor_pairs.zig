const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports accessor-pairs for object setters without getters" {
    const source =
        \\const object = {
        \\  set value(next) {},
        \\  get ready() { return true; },
        \\  set ready(next) {},
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.accessor_pairs.id));
    try std.testing.expectEqualStrings("Setter must be accompanied by a getter.", result.diagnostics[0].message);
}

test "reports accessor-pairs for class setters without getters" {
    const source =
        \\class Example {
        \\  set value(next) {}
        \\  static set count(next) {}
        \\  static get count() { return 1; }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.accessor_pairs.id));
}

test "reports accessor-pairs for property descriptors without get" {
    const source =
        \\Object.defineProperty(target, "value", {
        \\  set(next) {}
        \\});
        \\Object.defineProperties(target, {
        \\  first: {
        \\    set(next) {}
        \\  },
        \\  second: {
        \\    get() { return 1; },
        \\    set(next) {}
        \\  }
        \\});
        \\Object.create(proto, {
        \\  third: {
        \\    set(next) {}
        \\  }
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.accessor_pairs.id));
}

test "does not report accessor-pairs for getters without setters by default" {
    const source =
        \\const object = {
        \\  get value() { return 1; },
        \\};
        \\class Example {
        \\  get value() { return 1; }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.accessor_pairs.id));
}

test "does not treat ordinary descriptor-looking objects as property descriptors" {
    const source =
        \\const object = {
        \\  set(next) {},
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.accessor_pairs.id));
}

test "can disable accessor-pairs" {
    const source =
        \\const object = {
        \\  set value(next) {},
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .accessor_pairs = false,
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.accessor_pairs.id));
}
