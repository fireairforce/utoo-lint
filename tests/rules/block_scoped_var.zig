const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports block-scoped-var references outside binding context" {
    const source =
        \\function f() {
        \\  if (ok) {
        \\    var a = 1;
        \\  }
        \\  a;
        \\
        \\  for (var i = 0; i < 1; i++) {}
        \\  i;
        \\
        \\  switch (tag) {
        \\    case 1:
        \\      var s = 1;
        \\      break;
        \\  }
        \\  s;
        \\
        \\  {
        \\    var { b } = obj;
        \\  }
        \\  b;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.block_scoped_var.id));
}

test "does not report block-scoped-var references inside binding context" {
    const source =
        \\function f() {
        \\  if (ok) {
        \\    var a = 1;
        \\    a;
        \\  }
        \\
        \\  for (var i = 0; i < 1; i++) {
        \\    i;
        \\  }
        \\
        \\  switch (tag) {
        \\    case 1:
        \\      var s = 1;
        \\      s;
        \\      break;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.block_scoped_var.id));
}

test "can disable block-scoped-var" {
    const source =
        \\if (ok) {
        \\  var a = 1;
        \\}
        \\a;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .block_scoped_var = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.block_scoped_var.id));
}
