const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports for-direction for update expressions moving away from the stop condition" {
    const source =
        \\for (let i = 0; i < 10; i--) {
        \\  work(i);
        \\}
        \\for (let j = 10; j >= 0; ++j) {
        \\  work(j);
        \\}
        \\for (let k = 0; 10 > k; --k) {
        \\  work(k);
        \\}
        \\for (let l = 10; 0 <= l; l++) {
        \\  work(l);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.for_direction.id));
}

test "reports for-direction for assignment updates moving in the wrong direction" {
    const source =
        \\for (let i = 0; i < 10; i -= 1) {
        \\  work(i);
        \\}
        \\for (let j = 10; j > 0; j += 1) {
        \\  work(j);
        \\}
        \\for (let k = 0; k < 10; k = k - 1) {
        \\  work(k);
        \\}
        \\for (let l = 10; l > 0; l = 1 + l) {
        \\  work(l);
        \\}
        \\for (let m = 0; m < 10; other++, m--) {
        \\  work(m);
        \\}
        \\for (let n = 0; n < 10; n += -1) {
        \\  work(n);
        \\}
        \\for (let p = 10; p > 0; p -= -1) {
        \\  work(p);
        \\}
        \\for (let q = 0, limit = 10; q < limit; limit++) {
        \\  work(q);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 8), helpers.countRule(result, lint.rules.for_direction.id));
}

test "does not report for-direction for terminating update directions" {
    const source =
        \\for (let i = 0; i < 10; i++) {
        \\  work(i);
        \\}
        \\for (let j = 10; j > 0; j--) {
        \\  work(j);
        \\}
        \\for (let k = 0; 10 > k; k += 1) {
        \\  work(k);
        \\}
        \\for (let l = 10; 0 <= l; l -= 1) {
        \\  work(l);
        \\}
        \\for (let m = 0; m !== 10; m--) {
        \\  work(m);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.for_direction.id));
}

test "can disable for-direction" {
    const source =
        \\for (let i = 0; i < 10; i--) {
        \\  work(i);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .for_direction = false,
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.for_direction.id));
}
