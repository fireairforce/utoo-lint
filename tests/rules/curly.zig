const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports curly for control statements without block bodies" {
    const source =
        \\if (ready) run();
        \\else stop();
        \\while (ready) run();
        \\do run(); while (ready);
        \\for (let i = 0; i < 3; i++) run();
        \\for (const key in object) run();
        \\for (const item of items) run();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_for_in = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.curly.id));
}

test "does not report curly for block bodies or else-if chains" {
    const source =
        \\if (ready) { run(); }
        \\else if (waiting) { wait(); }
        \\else { stop(); }
        \\while (ready) { run(); }
        \\do { run(); } while (ready);
        \\for (let i = 0; i < 3; i++) { run(); }
        \\for (const key in object) { run(); }
        \\for (const item of items) { run(); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_for_in = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.curly.id));
}

test "can disable curly" {
    const source =
        \\if (ready) run();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.curly.id));
}
