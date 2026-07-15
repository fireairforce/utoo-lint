const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-lonely-if for if as only else block statement" {
    const source =
        \\if (first) {
        \\  runFirst();
        \\} else {
        \\  if (second) {
        \\    runSecond();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_else_return = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_lonely_if.id));
}

test "autofixes a lonely if into an else-if chain" {
    const source =
        \\if (first) {
        \\  runFirst();
        \\} else {
        \\  if (second) {
        \\    runSecond();
        \\  }
        \\}
    ;
    const expected =
        \\if (first) {
        \\  runFirst();
        \\} else if (second) {
        \\    runSecond();
        \\  }
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_else_return = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_lonely_if.id));
}

test "autofix preserves comments outside the else block and inside the child if" {
    const source =
        \\if (first) {
        \\  runFirst();
        \\} else /* outer */ {
        \\  if /* inner */ (second) {
        \\    runSecond();
        \\  }
        \\}
    ;
    const expected =
        \\if (first) {
        \\  runFirst();
        \\} else /* outer */ if /* inner */ (second) {
        \\    runSecond();
        \\  }
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_else_return = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_lonely_if.id));
}

test "does not autofix comments between the else braces and child if" {
    const source =
        \\if (first) {} else {
        \\  /* keep before */ if (second) {}
        \\}
        \\if (third) {} else {
        \\  if (fourth) {} /* keep after */
        \\}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result.result, lint.rules.no_lonely_if.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_lonely_if.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "does not report no-lonely-if when else block has multiple statements" {
    const source =
        \\if (first) {
        \\  runFirst();
        \\} else {
        \\  prepare();
        \\  if (second) {
        \\    runSecond();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_lonely_if.id));
}

test "does not report when else braces prevent a dangling else" {
    const source = "if (outer) if (first) {} else { if (second) {} } else {}";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_lonely_if.id));
}

test "does not autofix when removing braces could change ASI semantics" {
    const source =
        \\if (first) {} else { if (second) run() } follow();
        \\if (third) {} else {
        \\  if (fourth) run()
        \\}
        \\[1, 2, 3].forEach(run);
        \\if (fifth) {} else {
        \\  if (sixth) count++
        \\}
        \\use(count);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .eol_last = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result.result, lint.rules.no_lonely_if.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_lonely_if.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "autofixes ASI-sensitive shapes when consequents have semicolons" {
    const source =
        \\if (first) {} else{ if (second) run(); } follow();
        \\if (third) {} else {
        \\  if (fourth) run();
        \\}
        \\[1, 2, 3].forEach(run);
        \\if (fifth) {} else {
        \\  if (sixth) count++;
        \\}
        \\use(count);
    ;
    const expected =
        \\if (first) {} else if (second) run(); follow();
        \\if (third) {} else if (fourth) run();
        \\[1, 2, 3].forEach(run);
        \\if (fifth) {} else if (sixth) count++;
        \\use(count);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .eol_last = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_lonely_if.id));
}

test "can disable no-lonely-if" {
    const source =
        \\if (first) {
        \\  runFirst();
        \\} else {
        \\  if (second) {
        \\    runSecond();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_lonely_if = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_lonely_if.id));
}
