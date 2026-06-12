const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unused-labels for labels without labeled break or continue" {
    const source =
        \\outer: while (ready) {
        \\  break;
        \\}
        \\block: {
        \\  call();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_extra_label = false,
        .no_labels = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unused_labels.id));
    try std.testing.expectEqualStrings("Unused label.", result.diagnostics[0].message);
}

test "does not report no-unused-labels for used labels" {
    const source =
        \\outer: while (ready) {
        \\  break outer;
        \\}
        \\loop: while (ready) {
        \\  continue loop;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_extra_label = false,
        .no_labels = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unused_labels.id));
}

test "does not count label references inside nested functions" {
    const source =
        \\outer: while (ready) {
        \\  function nested() {
        \\    break outer;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_extra_label = false,
        .no_labels = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unused_labels.id));
}

test "can disable no-unused-labels" {
    const source =
        \\outer: while (ready) {
        \\  break;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_extra_label = false,
        .no_labels = false,
        .no_undef = false,
        .no_unused_labels = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unused_labels.id));
}
