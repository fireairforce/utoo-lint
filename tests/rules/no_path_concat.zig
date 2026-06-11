const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-path-concat for dirname and filename path string concatenation" {
    const source =
        \\const first = __dirname + "/foo.js";
        \\const second = __filename + "\\foo.js";
        \\const third = "/tmp/" + __dirname;
        \\const fourth = (__dirname) + `/foo.js`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_concat = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_path_concat.id));
}

test "does not report no-path-concat for non-path concatenation or path helpers" {
    const source =
        \\const name = __dirname + suffix;
        \\const label = __filename + ".bak";
        \\const joined = path.join(__dirname, "foo.js");
        \\const dynamic = __dirname + `${name}.js`;
        \\const ordinary = dirname + "/foo.js";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_concat = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_path_concat.id));
}

test "can disable no-path-concat" {
    const source =
        \\const first = __dirname + "/foo.js";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_path_concat = false,
        .no_useless_concat = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_path_concat.id));
}
