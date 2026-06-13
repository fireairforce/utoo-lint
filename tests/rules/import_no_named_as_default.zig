const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports import/no-named-as-default for default import names that are also named exports" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/mod.ts",
        .data =
        \\export default function actualDefault() {}
        \\export const Button = 1;
        ,
    });

    const source =
        \\import Button from "./mod";
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
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.import_no_named_as_default.id));
    try std.testing.expectEqualStrings(
        "Using exported name 'Button' as identifier for default import.",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "does not report import/no-named-as-default without a default export or matching named export" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/named-only.ts",
        .data = "export const Button = 1;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/default-only.ts",
        .data = "export default function actualDefault() {}\n",
    });

    const source =
        \\import Button from "./named-only";
        \\import Button from "./default-only";
        \\import Button from "pkg";
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
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_named_as_default.id));
}

test "can disable import/no-named-as-default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/mod.ts",
        .data =
        \\export default function actualDefault() {}
        \\export const Button = 1;
        ,
    });

    const source =
        \\import Button from "./mod";
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
        .import_no_named_as_default = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_named_as_default.id));
}
