const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-fallthrough for non-empty cases without abrupt completion" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    one();
        \\  case 2:
        \\    two();
        \\  default:
        \\    three();
        \\}
        \\switch (other) {
        \\  default:
        \\    fallback();
        \\  case 1:
        \\    one();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_fallthrough.id));
}

test "does not report no-fallthrough for break, return, throw, adjacent empty case, or fallthrough comments" {
    const source =
        \\function run(value) {
        \\  switch (value) {
        \\    case 1:
        \\      one();
        \\      break;
        \\    case 2:
        \\      return two();
        \\    case 3:
        \\      throw error;
        \\    case 4:
        \\    case 5:
        \\      five();
        \\      // falls through
        \\    default:
        \\      done();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_fallthrough.id));
}

test "does not report no-fallthrough when final try statements exit" {
    const source =
        \\function run(value) {
        \\  switch (value) {
        \\    case 1:
        \\      try { return one(); } catch (error) { recover(error); }
        \\    case 2:
        \\      try { one(); } finally { return cleanup(); }
        \\    case 3:
        \\      try { return three(); } finally { cleanup(); }
        \\    default:
        \\      done();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_fallthrough.id));
}

test "reports no-fallthrough when only catch exits" {
    const source =
        \\function run(value) {
        \\  switch (value) {
        \\    case 1:
        \\      try { one(); } catch (error) { return recover(error); }
        \\    default:
        \\      done();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_fallthrough.id));
}

test "reports no-fallthrough for separated empty cases by default" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\
        \\  case 2:
        \\    two();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_fallthrough.id));
}

test "allows separated empty cases when configured" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\
        \\  case 2:
        \\    two();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_fallthrough_allow_empty_case = .yes,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_fallthrough.id));
}

test "can disable no-fallthrough" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    one();
        \\  case 2:
        \\    two();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_fallthrough = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_fallthrough.id));
}
