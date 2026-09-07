const std = @import("std");
const lint = @import("utoo_lint");

test "reports explicit any types but not identifiers or strings named any" {
    const source =
        \\export type Alias = any;
        \\export function convert(value: any): any { return value; }
        \\export type Values = Array<any>;
        \\export const any = "any";
    ;
    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("@typescript-eslint/no-explicit-any", .{ .string = "error" });
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), result.diagnostics.len);
    for (result.diagnostics) |diagnostic| {
        try std.testing.expectEqualStrings("@typescript-eslint/no-explicit-any", diagnostic.rule_id);
        try std.testing.expectEqualStrings("Unexpected any. Specify a different type.", diagnostic.message);
        try std.testing.expectEqualStrings("any", source[diagnostic.span.start..diagnostic.span.end]);
        try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        try std.testing.expectEqual(@as(usize, 2), diagnostic.suggestions.len);
    }
}

test "fixToUnknown is opt-in and keeps editor suggestions" {
    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "[\"error\",{\"fixToUnknown\":true}]", .{});
    defer config.deinit();
    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("@typescript-eslint/no-explicit-any", config.value);
    var result = try lint.lintSource(std.testing.allocator, "type Value = any;", "fixture.ts", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), result.diagnostics.len);
    try std.testing.expectEqual(@as(usize, 1), result.diagnostics[0].fixes.len);
    try std.testing.expectEqualStrings("unknown", result.diagnostics[0].fixes[0].replacement);
    try std.testing.expectEqual(@as(usize, 2), result.diagnostics[0].suggestions.len);
}

test "ignoreRestArgs only exempts direct rest parameter array types" {
    const source =
        \\declare function a(...args: any[]): void;
        \\declare function b(...args: readonly any[]): void;
        \\declare function c(...args: Array<any>): void;
        \\declare function d(...args: ReadonlyArray<any>): void;
        \\type Callback = (...args: any[]) => void;
        \\type Constructor = new (...args: any[]) => object;
        \\interface Callable {
        \\  (...args: any[]): void;
        \\  new (...args: any[]): object;
        \\  run(...args: any[]): void;
        \\}
        \\const arrow = (...args: any[]) => {};
        \\class Methods { run(...args: any[]) {} }
        \\function ordinary(value: any, ...nested: any[][]) {}
        \\function other(...values: Promise<any>) {}
    ;
    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "[\"error\",{\"ignoreRestArgs\":true}]", .{});
    defer config.deinit();
    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("@typescript-eslint/no-explicit-any", config.value);
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), result.diagnostics.len);
}

test "scalar configuration resets explicit-any options and disabling the rule is respected" {
    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "[\"error\",{\"fixToUnknown\":true,\"ignoreRestArgs\":true}]", .{});
    defer config.deinit();
    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("@typescript-eslint/no-explicit-any", config.value);
    try options.setByRuleConfigValue("@typescript-eslint/no-explicit-any", .{ .string = "error" });
    try std.testing.expect(!options.typescript_eslint_no_explicit_any_fix_to_unknown);
    try std.testing.expect(!options.typescript_eslint_no_explicit_any_ignore_rest_args);
    try options.setByRuleConfigValue("@typescript-eslint/no-explicit-any", .{ .string = "off" });
    var result = try lint.lintSource(std.testing.allocator, "type Value = any;", "fixture.ts", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), result.diagnostics.len);
}
