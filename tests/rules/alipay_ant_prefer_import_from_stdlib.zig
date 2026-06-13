const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_prefer_import_from_stdlib = true;
    options.parser_semantic_errors = false;
    return options;
}

test "reports @alipay/ant/prefer-import-from-stdlib for smallfish dependency versions" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try writeProject(&tmp, "smallfish.config.js");
    const source =
        \\import lodash from 'lodash';
        \\import debounce from 'lodash/debounce';
        \\import cx from 'classnames';
        \\import dayjs from 'dayjs';
        \\import request from '@alipay/fm-request';
        \\import zustand from 'zustand/middleware';
        \\import lodashEs from 'lodash-es';
    ;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.alipay_ant_prefer_import_from_stdlib.id));
    try std.testing.expectEqualStrings(
        "推荐通过 smallfish:stdlib/lodash 使用 lodash, 可以统一依赖版本，防止 tree-shaking 失效。",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqualStrings(
        "推荐通过 smallfish:stdlib/request 使用 @alipay/fm-request, 可以统一依赖版本，防止 tree-shaking 失效。",
        result.diagnostics[4].message,
    );
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "reports @alipay/ant/prefer-import-from-stdlib for minifish stdlib package" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try writeProject(&tmp, "minifish.config.ts");
    const source = "import lodash from 'lodash';\n";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.alipay_ant_prefer_import_from_stdlib.id));
    try std.testing.expectEqualStrings(
        "推荐通过 @alipay/stdlib/lodash 使用 lodash, 可以统一依赖版本，防止 tree-shaking 失效。",
        result.diagnostics[0].message,
    );
}

test "does not report @alipay/ant/prefer-import-from-stdlib outside matching projects or versions" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package.json",
        .data =
        \\{
        \\  "dependencies": {
        \\    "lodash": "^3.10.1",
        \\    "dayjs": "workspace:*"
        \\  }
        \\}
        ,
    });
    const source =
        \\import lodash from 'lodash';
        \\import dayjs from 'dayjs';
        \\import already from 'smallfish:stdlib/lodash';
        \\import local from './lodash';
    ;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_import_from_stdlib.id));
}

test "can disable @alipay/ant/prefer-import-from-stdlib" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try writeProject(&tmp, "smallfish.config.js");
    const source = "import lodash from 'lodash';\n";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/entry.js", .data = source });

    const file_path = try entryPath(&tmp);
    defer std.testing.allocator.free(file_path);

    var options = optionsOnly();
    options.alipay_ant_prefer_import_from_stdlib = false;
    var result = try lint.lintSourceWithIo(std.testing.allocator, std.testing.io, source, file_path, options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_import_from_stdlib.id));
}

fn writeProject(tmp: *std.testing.TmpDir, config_name: []const u8) !void {
    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = config_name, .data = "export default {};\n" });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package.json",
        .data =
        \\{
        \\  "devDependencies": {
        \\    "lodash": "^3.10.1"
        \\  },
        \\  "dependencies": {
        \\    "lodash": "^4.17.21",
        \\    "classnames": "^2.3.2",
        \\    "lodash-es": "~4.17.21",
        \\    "@alipay/fm-request": "^1.0.0",
        \\    "dayjs": "^1.11.0",
        \\    "zustand": "^4.4.0"
        \\  }
        \\}
        ,
    });
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
