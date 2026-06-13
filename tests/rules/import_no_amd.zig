const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports import/no-amd for AMD dependency arrays" {
    const source =
        \\define(["dep"], function (dep) {});
        \\require(["dep"], function (dep) {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.import_no_amd.id));
    try std.testing.expectEqualStrings("Expected imports instead of AMD define().", result.diagnostics[0].message);
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "does not report import/no-amd for commonjs require calls" {
    const source =
        \\const dep = require("dep");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_amd.id));
}

test "can disable import/no-amd" {
    const source =
        \\define(["dep"], function (dep) {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .import_no_amd = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_amd.id));
}
