const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports vars-on-top for var declarations after statements and nested blocks" {
    const source =
        \\function run() {
        \\  doSomething();
        \\  var later = true;
        \\  if (later) {
        \\    var nested = true;
        \\  }
        \\}
        \\for (var i = 0; i < 10; i++) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .no_var = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.vars_on_top.id));
    try std.testing.expectEqualStrings("All 'var' declarations must be at the top of the function scope.", result.diagnostics[0].message);
}

test "allows leading var declarations after directives" {
    const source =
        \\"use strict";
        \\var first = true;
        \\var second = first;
        \\function run() {
        \\  "use strict";
        \\  var local = true;
        \\  var another = local;
        \\  return another;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .no_var = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.vars_on_top.id));
}

test "can disable vars-on-top" {
    const source =
        \\doSomething();
        \\var later = true;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .no_var = false,
        .vars_on_top = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.vars_on_top.id));
}
