const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports import/namespace for missing computed and destructured namespace members" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/mod.ts",
        .data =
        \\export default 1;
        \\export const named = 1;
        ,
    });

    const source =
        \\import * as ns from "./mod";
        \\ns.named;
        \\ns.default;
        \\ns.missing;
        \\ns["named"];
        \\const { named, missing } = ns;
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
        .no_undef = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_unused_expressions = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.import_namespace.id));
    try std.testing.expectEqualStrings("'missing' not found in imported namespace 'ns'.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Unable to validate computed reference to imported namespace 'ns'.", ruleDiagnostic(result, 1).message);
    try std.testing.expectEqualStrings("'missing' not found in imported namespace 'ns'.", ruleDiagnostic(result, 2).message);
    try std.testing.expectEqual(.@"error", ruleDiagnostic(result, 0).severity);
}

test "reports import/namespace for empty modules and namespace member assignment" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/empty.ts",
        .data = "export {};\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/mod.ts",
        .data = "export const named = 1;\n",
    });

    const source =
        \\import * as empty from "./empty";
        \\import * as ns from "./mod";
        \\ns.named = 2;
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
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.import_namespace.id));
    try std.testing.expectEqualStrings("No exported names found in module './empty'.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Assignment to member of namespace 'ns'.", ruleDiagnostic(result, 1).message);
}

test "can disable import/namespace" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/mod.ts",
        .data = "export const named = 1;\n",
    });

    const source =
        \\import * as ns from "./mod";
        \\ns.missing;
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
        .import_namespace = false,
        .import_newline_after_import = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_unused_expressions = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_namespace.id));
}

fn ruleDiagnostic(result: lint.Result, index: usize) lint.Diagnostic {
    var seen: usize = 0;
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.import_namespace.id)) continue;
        if (seen == index) return diagnostic;
        seen += 1;
    }
    unreachable;
}
