const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-process-env for process env member access" {
    const source =
        \\const nodeEnv = process.env.NODE_ENV;
        \\process.env.DEBUG = "1";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_process_env.id));
}

test "does not report no-process-env for other objects or dynamic properties" {
    const source =
        \\const env = config.env;
        \\const bracket = process["env"];
        \\const template = process[`env`];
        \\const env2 = process[envName];
        \\const computed = process[`${envName}`];
        \\const value = process.envName;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_process_env.id));
}

test "can disable no-process-env" {
    const source =
        \\const nodeEnv = process.env.NODE_ENV;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_process_env = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_process_env.id));
}
