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

test "autofixes control statement bodies with block statements" {
    const source =
        \\if (ready) run();
        \\else stop();
        \\while (ready) run();
        \\do run(); while (ready);
        \\for (let i = 0; i < 3; i++) run();
        \\for (const key in object) run();
        \\for (const item of items) run();
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_for_in = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\if (ready) {run();}
        \\else {stop();}
        \\while (ready) {run();}
        \\do {run();} while (ready);
        \\for (let i = 0; i < 3; i++) {run();}
        \\for (const key in object) {run();}
        \\for (const item of items) {run();}
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.curly.id));
}

test "autofix preserves comments around bodies when adding block statements" {
    const source =
        \\if (ready) /* before */ run(); // after
        \\while (ready)
        \\  /* keep */ run();
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\if (ready) /* before */ {run();} // after
        \\while (ready)
        \\  /* keep */ {run();}
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.curly.id));
}

test "autofixes unnecessary blocks for multi style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("curly", config.value);
    options.capitalized_comments = false;
    options.eol_last = false;
    options.no_for_in = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\if (ready) {run();}
        \\else{stop();}
        \\while (ready) {/* keep */ run();}
        \\do{run();}while (ready);
        \\for (let i = 0; i < 3; i++) {run();}
        \\for (const key in object) {run();}
        \\for (const item of items) {run();}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\if (ready) run();
        \\else stop();
        \\while (ready) /* keep */ run();
        \\do run();while (ready);
        \\for (let i = 0; i < 3; i++) run();
        \\for (const key in object) run();
        \\for (const item of items) run();
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.curly.id));
}

test "autofix refuses unsafe multi block removal" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("curly", config.value);
    options.eol_last = false;
    options.no_undef = false;
    options.no_unused_expressions = false;
    options.typescript_eslint_no_unused_expressions = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\if (safe) {run();}
        \\if (sameLine) {run()} follow();
        \\if (asiHazard) {run()}
        \\[1, 2, 3].forEach(run);
        \\if (outer) {if (inner) run();} else {stop();}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\if (safe) run();
        \\if (sameLine) {run()} follow();
        \\if (asiHazard) {run()}
        \\[1, 2, 3].forEach(run);
        \\if (outer) {if (inner) run();} else stop();
    , result.output);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result.result, lint.rules.curly.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.curly.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "autofix keeps nested control statements for multi-or-nest style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi-or-nest\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("curly", config.value);
    options.eol_last = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\if (ready) {run();}
        \\if (ready) {if (nested) run();}
        \\while (ready) {for (;;) stop();}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\if (ready) run();
        \\if (ready) {if (nested) run();}
        \\while (ready) {for (;;) stop();}
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.curly.id));
}

test "autofix refuses configured block additions that would not converge" {
    var multi_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi\"]",
        .{},
    );
    defer multi_config.deinit();

    var multi_options = lint.Options{};
    try multi_options.setByRuleConfigValue("curly", multi_config.value);
    multi_options.eol_last = false;
    multi_options.no_undef = false;
    multi_options.no_unused_vars = false;
    multi_options.parser_semantic_errors = false;

    const multi_source =
        \\if (ready)
        \\  run();
    ;
    var multi_result = try lint.lintSourceAndFix(std.testing.allocator, multi_source, "fixture.js", multi_options);
    defer multi_result.deinit(std.testing.allocator);

    try std.testing.expect(!multi_result.fixed);
    try std.testing.expectEqualStrings(multi_source, multi_result.output);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(multi_result.result, lint.rules.curly.id));
    try std.testing.expectEqual(@as(usize, 0), multi_result.result.diagnostics[0].fixes.len);

    var nested_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi-or-nest\"]",
        .{},
    );
    defer nested_config.deinit();

    var nested_options = multi_options;
    try nested_options.setByRuleConfigValue("curly", nested_config.value);

    const nested_source =
        \\if (simple)
        \\  run();
        \\if (outer) if (inner) run();
    ;
    var nested_result = try lint.lintSourceAndFix(std.testing.allocator, nested_source, "fixture.js", nested_options);
    defer nested_result.deinit(std.testing.allocator);

    try std.testing.expect(nested_result.fixed);
    try std.testing.expectEqualStrings(
        \\if (simple)
        \\  run();
        \\if (outer) {if (inner) run();}
    , nested_result.output);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(nested_result.result, lint.rules.curly.id));
    try std.testing.expectEqual(@as(usize, 0), nested_result.result.diagnostics[0].fixes.len);
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

test "autofixes configured curly multi-line style" {
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
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\if (singleLine) run();
        \\if (multiLine)
        \\  run();
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\if (singleLine) run();
        \\if (multiLine)
        \\  {run();}
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.curly.id));
}

test "supports configured curly multi style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi\"]",
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
        \\if (ready) { run(); }
        \\while (ready) { run(); }
        \\while (ready) { run(); step(); }
        \\for (const item of items) { run(); }
        \\if (ready) { let scoped = value; }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.curly.id));
}

test "supports configured curly multi-or-nest style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"multi-or-nest\"]",
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
        \\if (ready) if (nested) run();
        \\while (ready) for (let i = 0; i < 3; i++) run();
        \\if (ready) { run(); }
        \\if (ready) { if (nested) run(); }
        \\if (ready) { let scoped = value; }
        \\while (ready) { run(); step(); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.curly.id));
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
