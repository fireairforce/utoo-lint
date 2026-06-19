const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-restricted-exports for configured exported names" {
    const source =
        \\export const disallowed = 1;
        \\const local = 1;
        \\export { local as blocked };
        \\export { remote as denied } from "./mod";
    ;

    var options = baseOptions();
    try options.no_restricted_exports_names.append("disallowed");
    try options.no_restricted_exports_names.append("blocked");
    try options.no_restricted_exports_names.append("denied");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_restricted_exports.id));
    try std.testing.expect(hasMessage(result, "'blocked' is restricted from being used as an exported name."));
}

test "reports no-restricted-exports for variable destructuring names" {
    const source =
        \\export const { blocked, nested: { denied } } = source;
    ;

    var options = baseOptions();
    try options.no_restricted_exports_names.append("blocked");
    try options.no_restricted_exports_names.append("denied");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_restricted_exports.id));
}

test "supports restrictDefaultExports options" {
    const source =
        \\export default value;
        \\export { local as default };
        \\export { default } from "./mod";
        \\export { named as default } from "./mod";
        \\export * as default from "./mod";
    ;

    var options = baseOptions();
    options.no_restricted_exports_default = .{
        .direct = true,
        .named = true,
        .default_from = true,
        .named_from = true,
        .namespace_from = true,
    };

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_restricted_exports.id));
    try std.testing.expect(hasMessage(result, "Exporting 'default' is restricted."));
}

test "parses no-restricted-exports eslint config" {
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        \\["error", {"restrictedNamedExports": ["blocked"], "restrictDefaultExports": {"direct": true, "namedFrom": true}}]
    ,
        .{},
    );
    defer parsed.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-restricted-exports", parsed.value);

    try std.testing.expect(options.no_restricted_exports);
    try std.testing.expect(options.no_restricted_exports_names.contains("blocked"));
    try std.testing.expect(options.no_restricted_exports_default.direct);
    try std.testing.expect(options.no_restricted_exports_default.named_from);
    try std.testing.expect(!options.no_restricted_exports_default.named);
}

test "can disable no-restricted-exports" {
    const source =
        \\export const blocked = 1;
    ;

    var options = baseOptions();
    options.no_restricted_exports = false;
    try options.no_restricted_exports_names.append("blocked");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_restricted_exports.id));
}

fn baseOptions() lint.Options {
    return .{
        .no_restricted_exports = true,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_restricted_exports.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
