const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports unnecessary arrow body braces by default" {
    const source =
        \\const bad = () => { return value; };
        \\const ok = () => value;
        \\const multi = () => { work(); return value; };
        \\const bare = () => { return; };
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.arrow_body_style.id));
    try std.testing.expect(hasMessage(result, "Unexpected block statement surrounding arrow body"));
}

test "honors requireReturnForObjectLiteral" {
    const source =
        \\const keep = () => { return { value: true }; };
        \\const bad = () => { return value; };
    ;

    var options = baseOptions();
    options.arrow_body_style_require_return_for_object_literal = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.arrow_body_style.id));
}

test "reports concise bodies in always mode" {
    const source =
        \\const bad = () => value;
        \\const ok = () => { return value; };
    ;

    var options = baseOptions();
    options.arrow_body_style_style = .always;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.arrow_body_style.id));
    try std.testing.expect(hasMessage(result, "Expected block statement surrounding arrow body."));
}

test "never mode reports returned object literals too" {
    const source =
        \\const bad = () => { return { value: true }; };
    ;

    var options = baseOptions();
    options.arrow_body_style_style = .never;
    options.arrow_body_style_require_return_for_object_literal = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.arrow_body_style.id));
}

test "parses arrow-body-style config" {
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"as-needed\",{\"requireReturnForObjectLiteral\":true}]",
        .{},
    );
    defer parsed.deinit();

    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("arrow-body-style", parsed.value);

    try std.testing.expect(options.arrow_body_style);
    try std.testing.expectEqual(@as(@TypeOf(options.arrow_body_style_style), .as_needed), options.arrow_body_style_style);
    try std.testing.expect(options.arrow_body_style_require_return_for_object_literal);
}

test "can disable arrow-body-style" {
    const source =
        \\const bad = () => { return value; };
    ;

    var options = baseOptions();
    options.arrow_body_style = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.arrow_body_style.id));
}

fn baseOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.arrow_body_style = true;
    options.arrow_body_style_style = .as_needed;
    return options;
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.arrow_body_style.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
