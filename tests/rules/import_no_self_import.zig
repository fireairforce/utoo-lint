const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports import/no-self-import for relative imports that resolve to the current file" {
    const source =
        \\import first from "./button";
        \\import second from "../components/button.ts";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "src/components/button.ts", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.import_no_self_import.id));
    try std.testing.expectEqualStrings("Module imports itself.", result.diagnostics[0].message);
}

test "reports import/no-self-import for index module imports" {
    const source =
        \\import first from "./";
        \\import second from "./index";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "src/components/index.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.import_no_self_import.id));
}

test "does not report import/no-self-import for other modules or packages" {
    const source =
        \\import other from "./other";
        \\import react from "react";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "src/components/button.ts", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_self_import.id));
}

test "can disable import/no-self-import" {
    const source =
        \\import button from "./button";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "src/components/button.ts", .{
        .eol_last = false,
        .import_no_self_import = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_self_import.id));
}
