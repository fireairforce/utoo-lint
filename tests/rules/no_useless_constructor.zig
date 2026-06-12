const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-constructor for empty constructors without superclasses" {
    const source =
        \\class First {
        \\  constructor() {}
        \\}
        \\class Second {
        \\  constructor(value) {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_useless_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_useless_constructor.id));
    try std.testing.expectEqualStrings("Useless constructor.", result.diagnostics[0].message);
}

test "reports no-useless-constructor for pass-through super calls" {
    const source =
        \\class First extends Base {
        \\  constructor(...args) {
        \\    super(...args);
        \\  }
        \\}
        \\class Second extends Base {
        \\  constructor(a, b) {
        \\    super(a, b);
        \\  }
        \\}
        \\class Third extends Base {
        \\  constructor() {
        \\    super(...arguments);
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_useless_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_useless_constructor.id));
}

test "does not report no-useless-constructor for useful constructors" {
    const source =
        \\class First extends Base {
        \\  constructor(a = sideEffect()) {
        \\    super(a);
        \\  }
        \\}
        \\class Second extends Base {
        \\  constructor(a) {
        \\    super(transform(a));
        \\  }
        \\}
        \\class Third {
        \\  constructor() {
        \\    this.value = 1;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_useless_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_constructor.id));
}

test "can disable no-useless-constructor" {
    const source =
        \\class First {
        \\  constructor() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .no_useless_constructor = false,
        .typescript_eslint_no_useless_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_constructor.id));
}
