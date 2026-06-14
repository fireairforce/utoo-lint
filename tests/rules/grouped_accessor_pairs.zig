const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports grouped-accessor-pairs for object accessors separated by other properties" {
    const source =
        \\const object = {
        \\  get value() {
        \\    return 1;
        \\  },
        \\  other: 1,
        \\  set value(next) {},
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.grouped_accessor_pairs.id));
    try std.testing.expectEqualStrings("Getter and setter for 'value' should be grouped together.", result.diagnostics[0].message);
}

test "reports grouped-accessor-pairs for class accessors separated by other members" {
    const source =
        \\class Example {
        \\  get value() {
        \\    return this.x;
        \\  }
        \\  method() {}
        \\  set value(next) {
        \\    this.x = next;
        \\  }
        \\  static set count(next) {}
        \\  static method() {}
        \\  static get count() {
        \\    return 1;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.grouped_accessor_pairs.id));
}

test "allows adjacent accessors in either order and distinct static pairs" {
    const source =
        \\const object = {
        \\  set value(next) {},
        \\  get value() {
        \\    return 1;
        \\  },
        \\  get only() {
        \\    return 2;
        \\  },
        \\};
        \\class Example {
        \\  set value(next) {}
        \\  get value() {
        \\    return 1;
        \\  }
        \\  get only() {
        \\    return 2;
        \\  }
        \\  static get count() {
        \\    return 1;
        \\  }
        \\  static set count(next) {}
        \\  get shared() {
        \\    return 1;
        \\  }
        \\  static set shared(next) {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .accessor_pairs = false,
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.grouped_accessor_pairs.id));
}

test "reports grouped-accessor-pairs when getBeforeSet order is required" {
    const source =
        \\const object = {
        \\  set value(next) {},
        \\  get value() {
        \\    return 1;
        \\  },
        \\};
        \\class Example {
        \\  set value(next) {}
        \\  get value() {
        \\    return 1;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .accessor_pairs = false,
        .eol_last = false,
        .grouped_accessor_pairs_style = .get_before_set,
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.grouped_accessor_pairs.id));
}

test "reports grouped-accessor-pairs when setBeforeGet order is required" {
    const source =
        \\const object = {
        \\  get value() {
        \\    return 1;
        \\  },
        \\  set value(next) {},
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .grouped_accessor_pairs_style = .set_before_get,
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.grouped_accessor_pairs.id));
}

test "can disable grouped-accessor-pairs" {
    const source =
        \\const object = {
        \\  get value() {
        \\    return 1;
        \\  },
        \\  other: 1,
        \\  set value(next) {},
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .grouped_accessor_pairs = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.grouped_accessor_pairs.id));
}
