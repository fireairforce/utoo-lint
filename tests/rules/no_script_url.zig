const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-script-url for javascript urls" {
    const source =
        \\const first = "javascript:alert(1)";
        \\const second = `JaVaScRiPt:alert(2)`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_script_url.id));
}

test "does not report no-script-url for non-script urls or interpolated templates" {
    const source =
        \\const first = "https://example.com";
        \\const second = `java${scheme}:alert(1)`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_script_url.id));
}

test "can disable no-script-url" {
    const source =
        \\const url = "javascript:alert(1)";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_script_url = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_script_url.id));
}
