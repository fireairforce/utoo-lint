const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports read vars that are never assigned" {
    const source =
        \\let x;
        \\var y;
        \\console.log(x, y);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unassigned_vars.id));
    try std.testing.expect(hasMessage(result, "'x' is always 'undefined' because it's never assigned."));
    try std.testing.expect(hasMessage(result, "'y' is always 'undefined' because it's never assigned."));
}

test "ignores variables that are never read" {
    const source =
        \\let x;
        \\var y;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unassigned_vars.id));
}

test "ignores assigned variables and initialized declarations" {
    const source =
        \\let x;
        \\x = 1;
        \\console.log(x);
        \\var y;
        \\y++;
        \\console.log(y);
        \\let z = 1;
        \\console.log(z);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unassigned_vars.id));
}

test "ignores const declarations, destructuring, and ambient declarations" {
    const source =
        \\declare var ambient: string;
        \\const constant = 1;
        \\let { a } = obj;
        \\console.log(ambient, constant, a);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unassigned_vars.id));
}

test "can disable no-unassigned-vars" {
    const source =
        \\let x;
        \\console.log(x);
    ;

    var options = baseOptions();
    options.no_unassigned_vars = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unassigned_vars.id));
}

fn baseOptions() lint.Options {
    return .{
        .import_no_unresolved = false,
        .no_undef = false,
        .no_unassigned_vars = true,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_unassigned_vars.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
