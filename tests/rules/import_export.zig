const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports import/export for duplicate local exports" {
    const source =
        \\export default 1;
        \\export default 2;
        \\export const named = 1;
        \\export { named };
        \\const alias = 1;
        \\export { alias as named };
    ;

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, "fixture.ts", .{
        .eol_last = false,
        .import_newline_after_import = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.import_export.id));
    try std.testing.expectEqualStrings("Multiple default exports.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Multiple default exports.", ruleDiagnostic(result, 1).message);
    try std.testing.expectEqualStrings("Multiple exports of name 'named'.", ruleDiagnostic(result, 2).message);
    try std.testing.expectEqualStrings("Multiple exports of name 'named'.", ruleDiagnostic(result, 3).message);
    try std.testing.expectEqualStrings("Multiple exports of name 'named'.", ruleDiagnostic(result, 4).message);
    try std.testing.expectEqual(.warning, ruleDiagnostic(result, 0).severity);
}

test "reports import/export for duplicate star exports and empty star exports" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/one.ts",
        .data = "export const shared = 1;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/two.ts",
        .data = "export const shared = 2;\nexport const unique = 1;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/defaultOnly.ts",
        .data = "export default 1;\n",
    });

    const source =
        \\export * from "./one";
        \\export * from "./two";
        \\export * from "./defaultOnly";
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
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.import_export.id));
    try std.testing.expectEqualStrings("Multiple exports of name 'shared'.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Multiple exports of name 'shared'.", ruleDiagnostic(result, 1).message);
    try std.testing.expectEqualStrings("No named exports found in module './defaultOnly'.", ruleDiagnostic(result, 2).message);
}

test "can disable import/export" {
    const source =
        \\export default 1;
        \\export default 2;
    ;

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, "fixture.ts", .{
        .eol_last = false,
        .import_export = false,
        .import_newline_after_import = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_export.id));
}

fn ruleDiagnostic(result: lint.Result, index: usize) lint.Diagnostic {
    var seen: usize = 0;
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.import_export.id)) continue;
        if (seen == index) return diagnostic;
        seen += 1;
    }
    unreachable;
}
