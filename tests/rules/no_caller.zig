const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-caller for arguments caller and callee access" {
    const source =
        \\function f() {
        \\  arguments.callee;
        \\  arguments.caller;
        \\  arguments?.callee;
        \\  arguments.callee = fn;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_caller.id));
}

test "does not report no-caller for other objects or properties" {
    const source =
        \\object.callee;
        \\arguments.length;
        \\arguments[name];
        \\arguments["callee"];
        \\arguments["caller"];
        \\arguments[`callee`];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_caller.id));
}

test "can disable no-caller" {
    const source =
        \\arguments.callee;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_caller = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_caller.id));
}
