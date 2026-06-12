const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-extra-label for labels without labeled break or continue" {
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
        .no_labels = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_extra_label.id));
    try std.testing.expectEqualStrings("This label is unnecessary.", result.diagnostics[0].message);
}

test "does not report no-extra-label when labeled break or continue uses the label" {
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
        .no_labels = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_label.id));
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
        .no_labels = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_extra_label.id));
}

test "can disable no-extra-label" {
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
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_label.id));
}
