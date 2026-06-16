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

test "supports configured curly multi-line style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi-line\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("curly", config.value);
    options.eol_last = false;
    options.no_for_in = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\if (ready) run();
        \\if (ready)
        \\  run();
        \\while (ready) run();
        \\while (ready)
        \\  run();
        \\for (let i = 0; i < 3; i++) run();
        \\for (let i = 0; i < 3; i++)
        \\  run();
        \\for (const key in object) run();
        \\for (const key in object)
        \\  run();
        \\for (const item of items) run();
        \\for (const item of items)
        \\  run();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.curly.id));
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
