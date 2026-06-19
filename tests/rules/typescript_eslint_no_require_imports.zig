const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-require-imports for require imports" {
    const source =
        \\const fs = require('fs');
        \\import path = require('path');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_require_imports.id));
}

test "does not report @typescript-eslint/no-require-imports for local require functions" {
    const source =
        \\function require(name: string) {
        \\  return name;
        \\}
        \\const fs = require('fs');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_require_imports.id));
}

test "supports configured @typescript-eslint/no-require-imports allowAsImport option" {
    const source =
        \\const fs = require('fs');
        \\import path = require('path');
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowAsImport\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("@typescript-eslint/no-require-imports", config.value);
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_require_imports.id));
    try std.testing.expectEqualStrings("A `require()` style import is forbidden.", result.diagnostics[0].message);
}

test "can disable @typescript-eslint/no-require-imports" {
    const source =
        \\const fs = require('fs');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_require_imports = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_require_imports.id));
}
