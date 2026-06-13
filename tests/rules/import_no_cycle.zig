const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports import/no-cycle for direct and indirect relative import cycles" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/direct.ts",
        .data = "import { entry } from './entry';\nexport const direct = entry;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/middle.ts",
        .data = "import { leaf } from './leaf';\nexport const middle = leaf;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/leaf.ts",
        .data = "import { entry } from './entry';\nexport const leaf = entry;\n",
    });

    const source =
        \\import { direct } from './direct';
        \\import { middle } from './middle';
        \\export const entry = direct + middle;
    ;
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/entry.ts",
        .data = source,
    });
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
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.import_no_cycle.id));
    try std.testing.expectEqualStrings("Dependency cycle detected.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Dependency cycle via ./leaf:1", ruleDiagnostic(result, 1).message);
    try std.testing.expectEqual(.@"error", ruleDiagnostic(result, 0).severity);
}

test "ignores import/no-cycle type imports unresolved modules and self imports" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/typeOnly.ts",
        .data = "import type { Value } from './entry';\n",
    });

    const source =
        \\import type { Value } from './typeOnly';
        \\import './missing';
        \\import './entry';
        \\export type { Value } from './typeOnly';
    ;
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/entry.ts",
        .data = source,
    });
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
        .import_no_self_import = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_cycle.id));
}

test "can disable import/no-cycle" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/direct.ts",
        .data = "import { entry } from './entry';\nexport const direct = entry;\n",
    });

    const source = "import { direct } from './direct';\nexport const entry = direct;\n";
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/entry.ts",
        .data = source,
    });
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
        .import_no_cycle = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_cycle.id));
}

fn ruleDiagnostic(result: lint.Result, index: usize) lint.Diagnostic {
    var seen: usize = 0;
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.import_no_cycle.id)) continue;
        if (seen == index) return diagnostic;
        seen += 1;
    }
    unreachable;
}
