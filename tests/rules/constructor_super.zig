const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports constructor-super when derived constructors omit super" {
    const source =
        \\class Missing extends Base {
        \\  constructor() {}
        \\}
        \\class Conditional extends Base {
        \\  constructor(value) {
        \\    if (value) {
        \\      super();
        \\    }
        \\  }
        \\}
        \\class BareReturn extends Base {
        \\  constructor() {
        \\    return;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .no_useless_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.constructor_super.id));
}

test "does not report constructor-super for base constructors" {
    const source =
        \\class Base {
        \\  constructor() {
        \\    super();
        \\  }
        \\}
        \\class DuplicateBase {
        \\  constructor() {
        \\    super();
        \\    super();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .no_useless_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.constructor_super.id));
}

test "reports constructor-super for duplicate super calls" {
    const source =
        \\class Duplicate extends Base {
        \\  constructor() {
        \\    super();
        \\    super();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .no_useless_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.constructor_super.id));
}

test "does not report constructor-super for valid derived constructors" {
    const source =
        \\class NoConstructor extends Base {}
        \\class Direct extends Base {
        \\  constructor() {
        \\    super();
        \\  }
        \\}
        \\class Branches extends Base {
        \\  constructor(value) {
        \\    if (value) {
        \\      super();
        \\    } else {
        \\      super();
        \\    }
        \\  }
        \\}
        \\class Returns extends Base {
        \\  constructor() {
        \\    return {};
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .no_useless_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.constructor_super.id));
}

test "can disable constructor-super" {
    const source =
        \\class Missing extends Base {
        \\  constructor() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .constructor_super = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .no_useless_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.constructor_super.id));
}
