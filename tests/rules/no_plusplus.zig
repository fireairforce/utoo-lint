const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-plusplus for increment and decrement operators" {
    const source =
        \\let index = 0;
        \\index++;
        \\++index;
        \\index--;
        \\--index;
        \\for (let i = 0; i < 3; i++) {
        \\  run(i);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_plusplus.id));
}

test "does not report no-plusplus for compound assignments" {
    const source =
        \\let index = 0;
        \\index += 1;
        \\index -= 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_plusplus.id));
}

test "allows no-plusplus in for afterthoughts when configured" {
    const source =
        \\let index = 0;
        \\index++;
        \\for (let i = 0; i < 3; i++) {
        \\  run(i);
        \\}
        \\for (let i = 0, j = 3; i < j; i++, j--) {
        \\  run(i);
        \\}
        \\for (let i = 0; i < 3; (i++)) {
        \\  run(i);
        \\}
        \\for (let i = 0; i++ < 3;) {
        \\  run(i);
        \\}
        \\for (let i = 0, j = 0; i < 3; j = i++) {
        \\  run(i);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_plusplus_allow_for_loop_afterthoughts = .yes,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_plusplus.id));
}

test "can disable no-plusplus" {
    const source =
        \\let index = 0;
        \\index++;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_plusplus.id));
}
