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

test "supports configured import/no-cycle maxDepth option" {
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
    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"maxDepth\":1}]",
        .{},
    );
    defer config.deinit();

    var options = baseOptions();
    try options.setByRuleConfigValue("import/no-cycle", config.value);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.import_no_cycle.id));
    try std.testing.expectEqualStrings("Dependency cycle detected.", ruleDiagnostic(result, 0).message);
}

test "supports configured import/no-cycle commonjs dependencies" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/direct.js",
        .data = "const entry = require('./entry');\nmodule.exports = entry;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/middle.js",
        .data = "const leaf = require('./leaf');\nmodule.exports = leaf;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/leaf.js",
        .data = "const entry = require('./entry');\nmodule.exports = entry;\n",
    });

    const source =
        \\const direct = require('./direct');
        \\const middle = require('./middle');
        \\module.exports = direct + middle;
    ;
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/entry.js",
        .data = source,
    });
    const file_path = try fixturePath(&tmp, "entry.js");
    defer std.testing.allocator.free(file_path);

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"commonjs\":true}]",
        .{},
    );
    defer config.deinit();

    var options = baseOptions();
    try options.setByRuleConfigValue("import/no-cycle", config.value);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.import_no_cycle.id));
    try std.testing.expectEqualStrings("Dependency cycle detected.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Dependency cycle via ./leaf:1", ruleDiagnostic(result, 1).message);
}

test "allows import/no-cycle commonjs dependencies by default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/direct.js",
        .data = "const entry = require('./entry');\nmodule.exports = entry;\n",
    });

    const source = "const direct = require('./direct');\nmodule.exports = direct;\n";
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/entry.js",
        .data = source,
    });
    const file_path = try fixturePath(&tmp, "entry.js");
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_cycle.id));
}

test "supports configured import/no-cycle amd dependencies" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/direct.js",
        .data = "define(['./entry'], function (entry) { return entry; });\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/middle.js",
        .data = "require(['./leaf'], function (leaf) { return leaf; });\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/leaf.js",
        .data = "define(['./entry'], function (entry) { return entry; });\n",
    });

    const source =
        \\define(['./direct', './middle'], function (direct, middle) {
        \\  return direct + middle;
        \\});
    ;
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/entry.js",
        .data = source,
    });
    const file_path = try fixturePath(&tmp, "entry.js");
    defer std.testing.allocator.free(file_path);

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"amd\":true}]",
        .{},
    );
    defer config.deinit();

    var options = baseOptions();
    try options.setByRuleConfigValue("import/no-cycle", config.value);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.import_no_cycle.id));
    try std.testing.expectEqualStrings("Dependency cycle detected.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Dependency cycle via ./leaf:1", ruleDiagnostic(result, 1).message);
}

test "allows import/no-cycle amd dependencies by default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/direct.js",
        .data = "define(['./entry'], function (entry) { return entry; });\n",
    });

    const source = "define(['./direct'], function (direct) { return direct; });\n";
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/entry.js",
        .data = source,
    });
    const file_path = try fixturePath(&tmp, "entry.js");
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_cycle.id));
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

fn baseOptions() lint.Options {
    return .{
        .eol_last = false,
        .import_newline_after_import = false,
        .parser_semantic_errors = false,
    };
}

fn entryPath(tmp: *std.testing.TmpDir) ![]u8 {
    return fixturePath(tmp, "entry.ts");
}

fn fixturePath(tmp: *std.testing.TmpDir, name: []const u8) ![]u8 {
    return std.fs.path.resolve(std.testing.allocator, &.{
        ".zig-cache",
        "tmp",
        &tmp.sub_path,
        "src",
        name,
    });
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
