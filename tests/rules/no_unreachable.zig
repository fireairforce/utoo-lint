const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unreachable after abrupt statements" {
    const source =
        \\function first() {
        \\  return 1;
        \\  call();
        \\}
        \\function second() {
        \\  throw error;
        \\  call();
        \\}
        \\while (ready) {
        \\  break;
        \\  call();
        \\}
        \\while (ready) {
        \\  continue;
        \\  call();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_unreachable.id));
    try std.testing.expectEqualStrings("Unreachable code.", result.diagnostics[0].message);
}

test "reports no-unreachable after if statements where both branches exit" {
    const source =
        \\function run(value) {
        \\  if (value) {
        \\    return 1;
        \\  } else {
        \\    throw error;
        \\  }
        \\  call();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_else_return = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unreachable.id));
}

test "reports no-unreachable after try statements that exit" {
    const source =
        \\function first() {
        \\  try { return value; } catch (error) { throw error; }
        \\  call();
        \\}
        \\function second() {
        \\  try { use(); } finally { return cleanup(); }
        \\  call();
        \\}
        \\function third() {
        \\  try { throw error; } finally { cleanup(); }
        \\  call();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_unreachable.id));
}

test "does not report after try when catch can complete normally" {
    const source =
        \\async function render(ignoreError) {
        \\  try {
        \\    return await Promise.reject(new Error("render failed"));
        \\  } catch (error) {
        \\    if (!ignoreError) {
        \\      throw error;
        \\    }
        \\  }
        \\
        \\  return "fallback";
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unreachable.id));
}

test "does not report no-unreachable for reachable statements or hoisted declarations" {
    const source =
        \\function first(value) {
        \\  if (value) {
        \\    return 1;
        \\  }
        \\  call();
        \\}
        \\function second() {
        \\  return;
        \\  function later() {}
        \\  var hoisted;
        \\}
        \\function third() {
        \\  try { call(); } catch (error) { return recover(error); }
        \\  call();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unreachable.id));
}

test "reports no-unreachable for initialized var declarations after exits" {
    const source =
        \\function first() {
        \\  return;
        \\  var initialized = sideEffect();
        \\}
        \\function second() {
        \\  throw error;
        \\  var first, second = sideEffect();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unreachable.id));
}

test "reports no-unreachable in switch cases" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    break;
        \\    call();
        \\  default:
        \\    throw error;
        \\    call();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .default_case_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unreachable.id));
}

test "can disable no-unreachable" {
    const source =
        \\function run() {
        \\  return;
        \\  call();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unreachable = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unreachable.id));
}
