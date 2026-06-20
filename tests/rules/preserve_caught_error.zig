const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports rethrown errors without cause" {
    const source =
        \\try {
        \\  risky();
        \\} catch (err) {
        \\  throw new Error("failed");
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.preserve_caught_error.id));
    try std.testing.expect(hasMessage(result, "There is no `cause` attached to the symptom error being thrown."));
}

test "allows matching cause on built-in errors" {
    const source =
        \\try {
        \\  risky();
        \\} catch (err) {
        \\  throw new TypeError("failed", { cause: err });
        \\}
        \\try {
        \\  risky();
        \\} catch (error) {
        \\  throw new AggregateError([], "failed", { cause: error });
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.preserve_caught_error.id));
}

test "reports incorrect and shadowed causes" {
    const source =
        \\try {
        \\  risky();
        \\} catch (err) {
        \\  const other = err;
        \\  throw new Error("failed", { cause: other });
        \\}
        \\try {
        \\  risky();
        \\} catch (error) {
        \\  {
        \\    const error = otherError;
        \\    throw new Error("failed", { cause: error });
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.preserve_caught_error.id));
    try std.testing.expect(hasMessage(result, "The symptom error is being thrown with an incorrect `cause`."));
    try std.testing.expect(hasMessage(result, "The caught error is being attached as `cause`, but is shadowed by a closer scoped redeclaration."));
}

test "reports destructured catches and optional catch binding when configured" {
    const source =
        \\try {
        \\  risky();
        \\} catch ({ message }) {
        \\  throw new Error("failed");
        \\}
        \\try {
        \\  risky();
        \\} catch {
        \\  throw new Error("failed");
        \\}
    ;

    var options = baseOptions();
    options.preserve_caught_error_require_catch_parameter = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.preserve_caught_error.id));
    try std.testing.expect(hasMessage(result, "Re-throws cannot preserve the caught error as a part of it is being lost due to destructuring."));
    try std.testing.expect(hasMessage(result, "The caught error is not accessible because the catch clause lacks the error parameter."));
}

test "skips non-global error constructors and nested functions" {
    const source =
        \\function wrap(Error) {
        \\  try {
        \\    risky();
        \\  } catch (err) {
        \\    throw new Error("custom");
        \\  }
        \\}
        \\try {
        \\  risky();
        \\} catch (err) {
        \\  function later() {
        \\    throw new Error("not this catch");
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.preserve_caught_error.id));
}

test "parses preserve-caught-error config and can disable" {
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"requireCatchParameter\":true}]",
        .{},
    );
    defer parsed.deinit();

    var options = baseOptions();
    try options.setByRuleConfigValue("preserve-caught-error", parsed.value);
    try std.testing.expect(options.preserve_caught_error);
    try std.testing.expect(options.preserve_caught_error_require_catch_parameter);

    options.preserve_caught_error = false;
    var result = try lint.lintSource(std.testing.allocator, "try {} catch (err) { throw new Error('x'); }", "fixture.js", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.preserve_caught_error.id));
}

fn baseOptions() lint.Options {
    return .{
        .import_no_unresolved = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unassigned_vars = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .preserve_caught_error = true,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.preserve_caught_error.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
