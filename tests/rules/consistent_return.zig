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
