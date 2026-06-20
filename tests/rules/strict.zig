const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const StrictMode = @TypeOf(@as(lint.Options, .{}).strict_mode);

test "reports strict global mode when program directive is missing" {
    const source =
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options(.global));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.strict.id));
    try std.testing.expect(hasMessage(result, "Use the global form of 'use strict'."));
}

test "reports strict duplicate global directives" {
    const source =
        \\"use strict";
        \\"use strict";
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options(.global));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.strict.id));
    try std.testing.expect(hasMessage(result, "Multiple 'use strict' directives."));
}

test "reports strict function mode for top-level functions without directives" {
    const source =
        \\function run(value) {
        \\  return value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options(.function));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.strict.id));
    try std.testing.expect(hasMessage(result, "Use the function form of 'use strict'."));
}

test "allows strict function mode for function directives" {
    const source =
        \\function run(value) {
        \\  "use strict";
        \\  return value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options(.function));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.strict.id));
}

test "reports strict never mode and module directives" {
    const source =
        \\"use strict";
        \\const value = 1;
    ;

    var never_result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options(.never));
    defer never_result.deinit(std.testing.allocator);
    try std.testing.expect(hasMessage(never_result, "Strict mode is not permitted."));

    var module_result = try lint.lintSource(std.testing.allocator, source, "fixture.mjs", options(.safe));
    defer module_result.deinit(std.testing.allocator);
    try std.testing.expect(hasMessage(module_result, "'use strict' is unnecessary inside of modules."));
}

test "parses strict config mode" {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "[\"error\",\"never\"]", .{});
    defer parsed.deinit();

    var lint_options = baseOptions();
    try lint_options.setByRuleConfigValue("strict", parsed.value);

    try std.testing.expect(lint_options.strict);
    try std.testing.expectEqual(@as(StrictMode, .never), lint_options.strict_mode);
}

fn options(mode: StrictMode) lint.Options {
    var lint_options = baseOptions();
    lint_options.strict = true;
    lint_options.strict_mode = mode;
    return lint_options;
}

fn baseOptions() lint.Options {
    return .{
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.strict.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
