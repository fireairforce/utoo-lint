const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports consistent-return for mixed return values" {
    const source =
        "function valueThenBare(flag) {\n" ++
        "  if (flag) return 1;\n" ++
        "  return;\n" ++
        "}\n" ++
        "const bareThenValue = (flag) => {\n" ++
        "  if (flag) return;\n" ++
        "  return 1;\n" ++
        "};\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .no_unused_vars = false,
        .no_unused_expressions = false,
        .no_useless_return = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.consistent_return.id));
    try std.testing.expectEqualStrings("Expected a return value.", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("Expected no return value.", result.diagnostics[1].message);
}

test "supports configured consistent-return treatUndefinedAsUnspecified" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"treatUndefinedAsUnspecified\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("consistent-return", config.value);
    options.curly = false;
    options.no_undefined = false;
    options.no_unused_vars = false;
    options.no_useless_return = false;
    options.no_void = false;

    const source =
        "function undefinedThenBare(flag) {\n" ++
        "  if (flag) return undefined;\n" ++
        "  return;\n" ++
        "}\n" ++
        "const voidThenBare = (flag) => {\n" ++
        "  if (flag) return void 0;\n" ++
        "  return;\n" ++
        "};\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.consistent_return.id));
}

test "reports consistent-return when value-returning functions can fall through" {
    const source =
        "function maybeValue(flag) {\n" ++
        "  if (flag) return 1;\n" ++
        "}\n" ++
        "const maybeArrow = (flag) => {\n" ++
        "  if (flag) {\n" ++
        "    return 1;\n" ++
        "  }\n" ++
        "};\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .no_unused_vars = false,
        .no_unused_expressions = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.consistent_return.id));
    try std.testing.expectEqualStrings("Expected to return a value at the end of function.", result.diagnostics[0].message);
}

test "allows value-returning functions when all paths are terminal" {
    const source =
        "function bothBranches(flag) {\n" ++
        "  if (flag) {\n" ++
        "    return 1;\n" ++
        "  } else {\n" ++
        "    return 2;\n" ++
        "  }\n" ++
        "}\n" ++
        "function returnOrThrow(flag) {\n" ++
        "  if (flag) {\n" ++
        "    return 1;\n" ++
        "  }\n" ++
        "  throw error;\n" ++
        "}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.consistent_return.id));
}

test "scopes nested functions separately" {
    const source =
        "function values(flag) {\n" ++
        "  if (flag) return 1;\n" ++
        "  return 2;\n" ++
        "}\n" ++
        "function bare(flag) {\n" ++
        "  if (flag) return;\n" ++
        "  return;\n" ++
        "}\n" ++
        "function outer() {\n" ++
        "  function inner(flag) {\n" ++
        "    if (flag) return 1;\n" ++
        "    return;\n" ++
        "  }\n" ++
        "  return 1;\n" ++
        "}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .no_unused_vars = false,
        .no_useless_return = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.consistent_return.id));
}

test "can disable consistent-return" {
    const source =
        "function mixed(flag) {\n" ++
        "  if (flag) return 1;\n" ++
        "  return;\n" ++
        "}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .consistent_return = false,
        .no_unused_vars = false,
        .no_useless_return = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.consistent_return.id));
}
