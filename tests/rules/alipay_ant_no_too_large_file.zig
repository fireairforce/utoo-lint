const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_no_too_large_file = true;
    return options;
}

test "reports @alipay/ant/no-too-large-file above default line limit" {
    const source = try repeatedLines(501);
    defer std.testing.allocator.free(source);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.alipay_ant_no_too_large_file.id));
    try std.testing.expectEqualStrings("file: `/fixture.js` is too large 😨 (501 lines)`.", result.diagnostics[0].message);
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "allows @alipay/ant/no-too-large-file at default line limit" {
    const source = try repeatedLines(500);
    defer std.testing.allocator.free(source);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_too_large_file.id));
}

test "can disable @alipay/ant/no-too-large-file" {
    const source = try repeatedLines(501);
    defer std.testing.allocator.free(source);

    var options = optionsOnly();
    options.alipay_ant_no_too_large_file = false;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_too_large_file.id));
}

fn repeatedLines(lines: usize) ![]u8 {
    var source: std.ArrayList(u8) = .empty;
    errdefer source.deinit(std.testing.allocator);
    for (0..lines) |_| {
        try source.appendSlice(std.testing.allocator, "a();");
        if (lines > 1) try source.append(std.testing.allocator, '\n');
    }
    if (source.items.len > 0) _ = source.pop();
    return source.toOwnedSlice(std.testing.allocator);
}
