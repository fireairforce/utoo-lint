const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports import/no-named-as-default-member for default import member lookups that are named exports" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/mod.ts",
        .data =
        \\export default {};
        \\export const named = 1;
        \\export const other = 2;
        ,
    });

    const source =
        \\import mod from "./mod";
        \\mod.named;
        \\mod.default;
        \\mod.missing;
        \\const { other, missing } = mod;
    ;
    const file_path = try std.fs.path.resolve(std.testing.allocator, &.{
        ".zig-cache",
        "tmp",
        &tmp.sub_path,
        "src",
        "entry.ts",
    });
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, .{
        .eol_last = false,
        .import_newline_after_import = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_unused_expressions = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.import_no_named_as_default_member.id));
    try std.testing.expectEqualStrings(
        "Caution: `mod` also has a named export `named`. Check if you meant to write `import {named} from './mod'` instead.",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqualStrings(
        "Caution: `mod` also has a named export `other`. Check if you meant to write `import {other} from './mod'` instead.",
        result.diagnostics[1].message,
    );
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "does not report import/no-named-as-default-member for packages unresolved modules or missing properties" {
    const source =
        \\import mod from "pkg";
        \\mod.named;
    ;

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, "fixture.ts", .{
        .eol_last = false,
        .import_newline_after_import = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_unused_expressions = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_named_as_default_member.id));
}

test "can disable import/no-named-as-default-member" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/mod.ts",
        .data =
        \\export default {};
        \\export const named = 1;
        ,
    });

    const source =
        \\import mod from "./mod";
        \\mod.named;
    ;
    const file_path = try std.fs.path.resolve(std.testing.allocator, &.{
        ".zig-cache",
        "tmp",
        &tmp.sub_path,
        "src",
        "entry.ts",
    });
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, .{
        .eol_last = false,
        .import_newline_after_import = false,
        .import_no_named_as_default_member = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_unused_expressions = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_named_as_default_member.id));
}
