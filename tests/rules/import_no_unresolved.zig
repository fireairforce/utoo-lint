const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.import_no_unresolved = true;
    options.parser_semantic_errors = false;
    return options;
}

test "reports import/no-unresolved for missing static and dynamic imports" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    const source =
        \\import missing from './missing';
        \\export { value } from './also-missing';
        \\export * from './export-all-missing';
        \\import('./dynamic-missing');
    ;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.import_no_unresolved.id));
    try std.testing.expectEqualStrings("Unable to resolve path to module './missing'.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Unable to resolve path to module './also-missing'.", ruleDiagnostic(result, 1).message);
    try std.testing.expectEqualStrings("Unable to resolve path to module './export-all-missing'.", ruleDiagnostic(result, 2).message);
    try std.testing.expectEqualStrings("Unable to resolve path to module './dynamic-missing'.", ruleDiagnostic(result, 3).message);
}

test "allows import/no-unresolved resolved relative files directories and json files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src/dir");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/util.ts", .data = "export const util = 1;\n" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/dir/index.jsx", .data = "export const dir = 1;\n" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/data.json", .data = "{}\n" });
    const source =
        \\import { util } from './util';
        \\import { dir } from './dir';
        \\import data from './data.json';
    ;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_unresolved.id));
}

test "allows import/no-unresolved ignored prefixes builtins and packages" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src/node_modules/pkg/lib");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/node_modules/pkg/package.json", .data = "{\"main\":\"lib/main.js\"}\n" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/node_modules/pkg/lib/main.js", .data = "module.exports = 1;\n" });
    try tmp.dir.createDirPath(std.testing.io, "src/node_modules/@scope/pkg");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/node_modules/@scope/pkg/index.js", .data = "module.exports = 1;\n" });

    const source =
        \\import fs from 'fs';
        \\import path from 'node:path';
        \\import small from 'smallfish:foo';
        \\import mini from 'minifish:bar';
        \\import pkg from 'pkg';
        \\import scoped from '@scope/pkg';
    ;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_unresolved.id));
}

test "reports import/no-unresolved for missing packages" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    const source = "import missing from 'definitely-missing-package';\n";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.import_no_unresolved.id));
    try std.testing.expectEqualStrings("Unable to resolve path to module 'definitely-missing-package'.", ruleDiagnostic(result, 0).message);
}

test "supports configured import/no-unresolved ignore patterns" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    const source =
        \\import img from './missing.img';
        \\import virtual from 'virtual:module';
        \\import missing from './missing.js';
    ;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignore\":[\"\\\\.img$\",\"^virtual:\"]}]",
        .{},
    );
    defer config.deinit();

    var options = optionsOnly();
    try options.setByRuleConfigValue("import/no-unresolved", config.value);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.import_no_unresolved.id));
    try std.testing.expectEqualStrings("Unable to resolve path to module './missing.js'.", ruleDiagnostic(result, 0).message);
}

test "supports configured import/no-unresolved commonjs requires" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/resolved.js", .data = "module.exports = 1;\n" });
    const source =
        \\const resolved = require('./resolved');
        \\const missing = require('./missing');
        \\require(0);
        \\require(['./amd-missing'], function () {});
    ;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"commonjs\":true}]",
        .{},
    );
    defer config.deinit();

    var options = optionsOnly();
    try options.setByRuleConfigValue("import/no-unresolved", config.value);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.import_no_unresolved.id));
    try std.testing.expectEqualStrings("Unable to resolve path to module './missing'.", ruleDiagnostic(result, 0).message);
}

test "allows import/no-unresolved commonjs requires by default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    const source = "const missing = require('./missing');\n";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_unresolved.id));
}

test "supports configured import/no-unresolved amd dependencies" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/resolved.js", .data = "define(function () { return 1; });\n" });
    const source =
        \\define(['./resolved', './missing-define'], function () {});
        \\require(['./missing-require'], function () {});
        \\require('./commonjs-missing');
    ;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"amd\":true}]",
        .{},
    );
    defer config.deinit();

    var options = optionsOnly();
    try options.setByRuleConfigValue("import/no-unresolved", config.value);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.import_no_unresolved.id));
    try std.testing.expectEqualStrings("Unable to resolve path to module './missing-define'.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Unable to resolve path to module './missing-require'.", ruleDiagnostic(result, 1).message);
}

test "allows import/no-unresolved amd dependencies by default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    const source = "define(['./missing'], function () {});\n";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_unresolved.id));
}

test "can disable import/no-unresolved" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    const source = "import missing from './missing';\n";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var options = optionsOnly();
    options.import_no_unresolved = false;
    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_no_unresolved.id));
}

fn entryPath(tmp: *std.testing.TmpDir) ![]u8 {
    return std.fs.path.resolve(std.testing.allocator, &.{
        ".zig-cache",
        "tmp",
        &tmp.sub_path,
        "src",
        "entry.js",
    });
}

fn ruleDiagnostic(result: lint.Result, index: usize) lint.Diagnostic {
    var seen: usize = 0;
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.import_no_unresolved.id)) continue;
        if (seen == index) return diagnostic;
        seen += 1;
    }
    unreachable;
}
