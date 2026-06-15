const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-setter-return for returning values from class and object setters" {
    const source =
        \\class Example {
        \\  set value(next) {
        \\    return next;
        \\  }
        \\}
        \\const object = {
        \\  set value(next) {
        \\    return next;
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_setter_return.id));
}

test "reports no-setter-return for common property descriptor setters" {
    const source =
        \\const suffix = "Property";
        \\Object.defineProperty(object, "value", {
        \\  set(next) {
        \\    return next;
        \\  },
        \\});
        \\Object["defineProperty"](object, "string", {
        \\  set(next) {
        \\    return next;
        \\  },
        \\});
        \\Object[`defineProperty`](object, "template", {
        \\  set(next) {
        \\    return next;
        \\  },
        \\});
        \\Object[`define${suffix}`](object, "dynamic", {
        \\  set(next) {
        \\    return next;
        \\  },
        \\});
        \\Object.defineProperties(object, {
        \\  value: {
        \\    set(next) {
        \\      return next;
        \\    },
        \\  },
        \\});
        \\Object["defineProperties"](object, {
        \\  string: {
        \\    set(next) {
        \\      return next;
        \\    },
        \\  },
        \\});
        \\Object[`defineProperties`](object, {
        \\  template: {
        \\    set(next) {
        \\      return next;
        \\    },
        \\  },
        \\});
        \\Object.create(proto, {
        \\  value: {
        \\    set: function(next) {
        \\      return next;
        \\    },
        \\  },
        \\});
        \\Object["create"](proto, {
        \\  string: {
        \\    set(next) {
        \\      return next;
        \\    },
        \\  },
        \\});
        \\Object[`create`](proto, {
        \\  template: {
        \\    set(next) {
        \\      return next;
        \\    },
        \\  },
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 9), helpers.countRule(result, lint.rules.no_setter_return.id));
}

test "does not report no-setter-return for bare returns methods or nested functions" {
    const source =
        \\class Example {
        \\  set value(next) {
        \\    return;
        \\    function nested() {
        \\      return next;
        \\    }
        \\    const arrow = () => {
        \\      return next;
        \\    };
        \\  }
        \\  method() {
        \\    return next;
        \\  }
        \\}
        \\const object = {
        \\  set: function(next) {
        \\    return next;
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_setter_return.id));
}

test "can disable no-setter-return" {
    const source =
        \\class Example {
        \\  set value(next) {
        \\    return next;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_setter_return = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_setter_return.id));
}
