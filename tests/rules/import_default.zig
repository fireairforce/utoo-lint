const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports import/default for default imports without a default export" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.createDirPath(std.testing.io, "src/dir");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/named.ts",
        .data = "export const named = 1;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/has-default.ts",
        .data = "export default function Component() {}\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/dir/index.ts",
        .data = "export default class FromIndex {}\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/reexport.ts",
        .data = "export { default } from './has-default';\n",
    });

    const source =
        \\import missing from "./named";
        \\import present from "./has-default";
        \\import indexed from "./dir";
        \\import reexported from "./reexport";
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
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.import_default.id));
    try std.testing.expectEqualStrings(
        "No default export found in imported module \"./named\".",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "reports import/default when a default re-export target has no default export" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/named.ts",
        .data = "export const named = 1;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/reexport.ts",
        .data = "export { default } from './named';\n",
    });

    const source =
        \\import missing from "./reexport";
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
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.import_default.id));
    try std.testing.expectEqualStrings(
        "No default export found in imported module \"./reexport\".",
        result.diagnostics[0].message,
    );
}

test "does not report import/default for side effect named type or unresolved imports" {
    const source =
        \\import "./setup";
        \\import type TypeOnly from "./named";
        \\import { named } from "./named";
        \\import pkg from "pkg";
    ;

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, "fixture.ts", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_default.id));
}

test "can disable import/default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/named.ts",
        .data = "export const named = 1;\n",
    });

    const source =
        \\import missing from "./named";
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
        .import_default = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_default.id));
}
