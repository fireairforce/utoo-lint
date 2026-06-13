const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @alipay/ant/no-import-src for package src imports" {
    const source =
        \\import direct from "src";
        \\import trailing from "src/";
        \\import nested from "src/features/button";
        \\import scoped from "@scope/pkg/src/components/button";
        \\import packageSrc from "foo-bar/src";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.alipay_ant_no_import_src.id));
    try std.testing.expectEqualStrings(
        "Import code from 'src' may break your App for compatibility issues.",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "does not report @alipay/ant/no-import-src for relative or non-matching imports" {
    const source =
        \\import relative from "./src";
        \\import parent from "../src";
        \\import prefixed from "src_utils/button";
        \\import invalidSegment from "src/_internal";
        \\import packageRoot from "@scope/pkg";
        \\import doubleSlash from "pkg//src";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_import_src.id));
}

test "can disable @alipay/ant/no-import-src" {
    const source =
        \\import direct from "src/features/button";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_ant_no_import_src = false,
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_import_src.id));
}
