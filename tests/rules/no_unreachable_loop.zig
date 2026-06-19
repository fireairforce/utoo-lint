const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unreachable-loop for loops that always exit" {
    const source =
        \\function run(items, object) {
        \\  while (items.length) {
        \\    break;
        \\  }
        \\  do {
        \\    throw new Error("stop");
        \\  } while (items.length);
        \\  for (;;) {
        \\    return;
        \\  }
        \\  for (const key in object) {
        \\    if (key) {
        \\      break;
        \\    } else {
        \\      throw new Error("stop");
        \\    }
        \\  }
        \\  for (const item of items) {
        \\    if (item) {
        \\      return item;
        \\    } else {
        \\      throw new Error("stop");
        \\    }
        \\  }
        \\}
        \\
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_unreachable_loop.id));
    try std.testing.expectEqualStrings("This loop will never iterate more than once.", result.diagnostics[0].message);
}

test "allows no-unreachable-loop when a later iteration can be reached" {
    const source =
        \\function run(items) {
        \\  while (items.length) {
        \\    if (items.shift()) {
        \\      break;
        \\    }
        \\    work();
        \\  }
        \\  for (;;) {
        \\    if (ready()) {
        \\      return;
        \\    }
        \\    work();
        \\  }
        \\  for (const item of items) {
        \\    while (item.pending) {
        \\      if (done()) {
        \\        break;
        \\      }
        \\      workInner();
        \\    }
        \\    work(item);
        \\  }
        \\}
        \\
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unreachable_loop.id));
}

test "reports no-unreachable-loop for switches whose cases always exit" {
    const source =
        \\function run(items, value) {
        \\  while (items.length) {
        \\    switch (value) {
        \\      case 1:
        \\        return;
        \\      default:
        \\        throw new Error("stop");
        \\    }
        \\  }
        \\}
        \\
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unreachable_loop.id));
}

test "does not treat switch break as loop exit" {
    const source =
        \\function run(items, value) {
        \\  while (items.length) {
        \\    switch (value) {
        \\      default:
        \\        break;
        \\    }
        \\    work();
        \\  }
        \\}
        \\
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unreachable_loop.id));
}

test "can ignore no-unreachable-loop loop kinds" {
    const source =
        \\function run(items) {
        \\  while (items.length) {
        \\    break;
        \\  }
        \\  for (const item of items) {
        \\    break;
        \\  }
        \\}
        \\
    ;

    var options = baseOptions();
    options.no_unreachable_loop_ignore_while = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unreachable_loop.id));
}

test "can disable no-unreachable-loop" {
    const source =
        \\while (condition) {
        \\  break;
        \\}
        \\
    ;

    var options = baseOptions();
    options.no_unreachable_loop = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unreachable_loop.id));
}

fn baseOptions() lint.Options {
    return .{
        .consistent_return = false,
        .no_constant_condition = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}
