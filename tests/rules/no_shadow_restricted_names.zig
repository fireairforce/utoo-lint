const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-shadow-restricted-names for restricted declarations" {
    const source =
        \\function NaN() {}
        \\!function(Infinity) {};
        \\const undefined = 5;
        \\try {} catch (eval) {}
        \\import { undefined } from "bar";
        \\import * as arguments from "baz";
        \\class Infinity {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_const_assign = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_eval = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_shadow_restricted_names.id));
}

test "reports no-shadow-restricted-names inside binding patterns" {
    const source =
        \\function f({ NaN }, [Infinity], ...eval) {}
        \\const { undefined: alias = 1 } = source;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_shadow_restricted_names.id));
}

test "does not report no-shadow-restricted-names for allowed names or uninitialized undefined" {
    const source =
        \\let Object;
        \\function f(a, b) {}
        \\let undefined;
        \\var undefined;
        \\import { undefined as undef } from "bar";
        \\const foo = globalThis;
        \\function global(globalThis) {}
        \\const { value: globalThis } = source;
        \\import globalThis from "foo";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_undef_init = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_shadow_restricted_names.id));
}

test "can disable no-shadow-restricted-names" {
    const source =
        \\const NaN = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_shadow_restricted_names = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_shadow_restricted_names.id));
}
