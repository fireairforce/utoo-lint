const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.eslint_comments_no_restricted_disable = true;
    options.eslint_comments_no_restricted_disable_no_nested_ternary = true;
    return options;
}

test "reports eslint-comments/no-restricted-disable for restricted disable comments" {
    const source =
        \\/* eslint-disable no-nested-ternary */
        \\// eslint-disable-next-line no-console, no-nested-ternary
        \\const value = foo ? bar ? 1 : 2 : 3;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.eslint_comments_no_restricted_disable.id));
    try std.testing.expectEqualStrings("Disabling 'no-nested-ternary' is not allowed.", result.diagnostics[0].message);
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "reports eslint-comments/no-restricted-disable for disable all comments" {
    const source =
        \\// eslint-disable-next-line -- reason
        \\const value = foo ? bar ? 1 : 2 : 3;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.eslint_comments_no_restricted_disable.id));
}

test "allows eslint-comments/no-restricted-disable for unrestricted comments" {
    const source =
        \\/* eslint-disable no-console */
        \\// eslint-enable no-nested-ternary
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.eslint_comments_no_restricted_disable.id));
}

test "can disable eslint-comments/no-restricted-disable" {
    const source = "/* eslint-disable no-nested-ternary */\n";
    var options = optionsOnly();
    options.eslint_comments_no_restricted_disable = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.eslint_comments_no_restricted_disable.id));
}
