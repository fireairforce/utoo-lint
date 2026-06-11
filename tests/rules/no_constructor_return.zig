const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-constructor-return for returning values from constructors" {
    const source =
        \\class First {
        \\  constructor() {
        \\    return {};
        \\  }
        \\}
        \\class Second {
        \\  constructor() {
        \\    return value;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_constructor_return.id));
}

test "does not report no-constructor-return for bare returns methods or nested functions" {
    const source =
        \\class Example {
        \\  constructor() {
        \\    return;
        \\    function nested() {
        \\      return value;
        \\    }
        \\    const arrow = () => {
        \\      return value;
        \\    };
        \\  }
        \\  method() {
        \\    return value;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_constructor_return.id));
}

test "can disable no-constructor-return" {
    const source =
        \\class First {
        \\  constructor() {
        \\    return {};
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_constructor_return = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_constructor_return.id));
}
