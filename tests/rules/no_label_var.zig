const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-label-var for labels that share a variable name" {
    const source =
        \\var outer = 1;
        \\outer: while (outer) {
        \\  break outer;
        \\}
        \\
        \\function run(inner) {
        \\  inner: for (;;) {
        \\    break inner;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_extra_label = false,
        .no_labels = false,
        .no_unused_labels = false,
        .no_unused_vars = false,
        .no_var = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_label_var.id));
    try std.testing.expectEqualStrings("Found identifier with same name as label.", result.diagnostics[0].message);
}

test "does not report no-label-var for unrelated scopes" {
    const source =
        \\outer: while (true) {
        \\  break outer;
        \\}
        \\
        \\function run() {
        \\  var outer = 1;
        \\  return outer;
        \\}
        \\
        \\block: {
        \\  const inner = 1;
        \\  break block;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_extra_label = false,
        .no_labels = false,
        .no_unused_labels = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_label_var.id));
}

test "can disable no-label-var" {
    const source =
        \\let name = 1;
        \\name: while (name) {
        \\  break name;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_extra_label = false,
        .no_label_var = false,
        .no_labels = false,
        .no_unused_labels = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_label_var.id));
}
