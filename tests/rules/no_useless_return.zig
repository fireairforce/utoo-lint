const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-return at natural function exits" {
    const source =
        \\function first() {
        \\  work();
        \\  return;
        \\}
        \\function second(flag) {
        \\  if (flag) {
        \\    return;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_useless_return.id));
    try std.testing.expectEqualStrings("Unnecessary return statement.", result.diagnostics[0].message);
}

test "reports no-useless-return in final switch cases" {
    const source =
        \\function check(value) {
        \\  switch (value) {
        \\    case 1:
        \\      run();
        \\      return;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_useless_return.id));
}

test "reports no-useless-return in final try blocks" {
    const source =
        \\function first() {
        \\  try {
        \\    work();
        \\    return;
        \\  } catch (error) {
        \\    recover(error);
        \\  }
        \\}
        \\function second() {
        \\  try {
        \\    return;
        \\  } finally {
        \\    cleanup();
        \\  }
        \\}
        \\function third() {
        \\  try {
        \\    work();
        \\  } catch (error) {
        \\    return;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_useless_return.id));
}

test "does not report no-useless-return when return changes control flow" {
    const source =
        \\function first(flag) {
        \\  if (flag) {
        \\    return;
        \\  }
        \\  work();
        \\}
        \\function second(items) {
        \\  while (items.length) {
        \\    return;
        \\  }
        \\}
        \\function third(value) {
        \\  switch (value) {
        \\    case 1:
        \\      return;
        \\    case 2:
        \\      work();
        \\  }
        \\}
        \\function fourth() {
        \\  return value;
        \\}
        \\function fifth() {
        \\  try {
        \\    work();
        \\  } finally {
        \\    return;
        \\  }
        \\}
        \\function sixth() {
        \\  try {
        \\    work();
        \\  } catch (error) {
        \\    return;
        \\  } finally {
        \\    cleanup();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_return.id));
}

test "can disable no-useless-return" {
    const source =
        \\function first() {
        \\  return;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .no_useless_return = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_return.id));
}

test "autofixes redundant returns in statement lists" {
    const source =
        \\function first() { work(); return; }
        \\function second(flag) { if (flag) { return; } }
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\function first() { work();  }
        \\function second(flag) { if (flag) {  } }
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_useless_return.id));
}

test "does not autofix non-list or commented redundant returns" {
    const source =
        \\function first(flag) { if (flag) return; }
        \\function second() { return/**/; }
        \\function third() { return// keep
        \\}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result.result, lint.rules.no_useless_return.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_useless_return.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}
