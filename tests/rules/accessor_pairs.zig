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

test "reports accessor-pairs for computed setters without getters" {
    const source =
        \\const object = {
        \\  set [`template`](next) {},
        \\  set [dynamic](next) {},
        \\  get [paired]() { return 1; },
        \\  set [paired](next) {},
        \\};
        \\class Example {
        \\  set [`template`](next) {}
        \\  set [dynamic](next) {}
        \\  get [paired]() { return 1; }
        \\  set [paired](next) {}
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

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.accessor_pairs.id));
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

test "reports accessor-pairs for getters without setters when enabled" {
    const source =
        \\const object = {
        \\  get value() { return 1; },
        \\};
        \\class Example {
        \\  get value() { return 1; }
        \\}
        \\Object.defineProperty(target, "value", {
        \\  get() { return 1; }
        \\});
        \\Object.defineProperties(target, {
        \\  first: {
        \\    get() { return 1; }
        \\  },
        \\  second: {
        \\    get() { return 1; },
        \\    set(next) {}
        \\  }
        \\});
        \\Object.create(proto, {
        \\  third: {
        \\    get() { return 1; }
        \\  }
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .accessor_pairs_get_without_set = .yes,
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.accessor_pairs.id));
    try std.testing.expectEqualStrings("Getter must be accompanied by a setter.", result.diagnostics[0].message);
}

test "does not report accessor-pairs for setters without getters when disabled" {
    const source =
        \\const object = {
        \\  set value(next) {},
        \\  get ready() { return true; },
        \\};
        \\class Example {
        \\  set value(next) {}
        \\  get ready() { return true; }
        \\}
        \\Object.defineProperty(target, "value", {
        \\  set(next) {}
        \\});
        \\Object.defineProperties(target, {
        \\  first: {
        \\    set(next) {}
        \\  },
        \\  second: {
        \\    get() { return 1; }
        \\  }
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .accessor_pairs_get_without_set = .yes,
        .accessor_pairs_set_without_get = .no,
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.accessor_pairs.id));
    try std.testing.expectEqualStrings("Getter must be accompanied by a setter.", result.diagnostics[0].message);
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
