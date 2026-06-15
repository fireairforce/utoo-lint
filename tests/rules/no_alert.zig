const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-alert for global alert APIs" {
    const source =
        \\alert("here");
        \\confirm("continue?");
        \\prompt("name");
        \\window.alert("hello");
        \\globalThis.prompt("name");
        \\window["confirm"]("continue?");
        \\window[`alert`]("hello");
        \\globalThis[`prompt`]("name");
        \\(alert)("wrapped");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 9), helpers.countRule(result, lint.rules.no_alert.id));
}

test "does not report no-alert for shadowed alert" {
    const source =
        \\const alert = customAlert;
        \\alert("custom");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_alert.id));
}

test "does not report no-alert for dynamic global member names" {
    const source =
        \\window[`al${suffix}`]("hello");
        \\globalThis[name]("name");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_alert.id));
}

test "can disable no-alert" {
    const source =
        \\alert("here");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_alert = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_alert.id));
}
