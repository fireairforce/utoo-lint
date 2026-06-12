const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports getter-return for getters that do not return a value" {
    const source =
        \\class Example {
        \\  get missing() {}
        \\  get bare() {
        \\    return;
        \\  }
        \\  get partial() {
        \\    if (ready) {
        \\      return 1;
        \\    }
        \\  }
        \\}
        \\const obj = {
        \\  get missing() {},
        \\  get bare() {
        \\    return;
        \\  },
        \\  get nestedOnly() {
        \\    function nested() {
        \\      return 1;
        \\    }
        \\  },
        \\  get unreachableValue() {
        \\    return;
        \\    return 1;
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.getter_return.id));
}

test "reports getter-return for descriptor getters that do not return a value" {
    const source =
        \\Object.defineProperty(target, "x", {
        \\  get: function () {}
        \\});
        \\Object.defineProperties(target, {
        \\  y: {
        \\    get() {
        \\      if (ready) {
        \\        return 1;
        \\      }
        \\    }
        \\  }
        \\});
        \\Object.create(proto, {
        \\  z: {
        \\    get: function () {
        \\      return;
        \\    }
        \\  }
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.getter_return.id));
}

test "does not report getter-return when all getter paths return or throw" {
    const source =
        \\class Example {
        \\  get value() {
        \\    return 1;
        \\  }
        \\  get branch() {
        \\    if (ready) {
        \\      return 1;
        \\    } else {
        \\      return 2;
        \\    }
        \\  }
        \\  get error() {
        \\    throw new Error("missing");
        \\  }
        \\}
        \\const obj = {
        \\  get value() {
        \\    return 1;
        \\  },
        \\  get branch() {
        \\    if (ready) {
        \\      throw new Error("missing");
        \\    }
        \\    return 2;
        \\  },
        \\  get: function () {}
        \\};
        \\Object.defineProperty(target, "x", {
        \\  get: function () {
        \\    return value;
        \\  }
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.getter_return.id));
}

test "can disable getter-return" {
    const source =
        \\class Example {
        \\  get missing() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .getter_return = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.getter_return.id));
}
