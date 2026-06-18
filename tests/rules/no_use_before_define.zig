const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-use-before-define for references before declarations" {
    const source =
        \\f();
        \\function f() {}
        \\
        \\new C();
        \\class C {}
        \\
        \\a;
        \\var a = 1;
        \\
        \\var b = b;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_no_use_before_define = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_use_before_define.id));
}

test "does not report no-use-before-define for references after declarations" {
    const source =
        \\function f() {}
        \\f();
        \\
        \\class C {}
        \\new C();
        \\
        \\var a = 1;
        \\a;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_no_use_before_define = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_use_before_define.id));
}

test "reports no-use-before-define for repeated initializer self references" {
    const source =
        \\var a = a;
        \\var a = a;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_redeclare = false,
        .no_unused_vars = false,
        .typescript_eslint_no_use_before_define = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_use_before_define.id));
}

test "uses configured no-use-before-define function and class checks" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"functions\":false,\"classes\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-use-before-define", config.value);
    options.eol_last = false;
    options.no_empty_block_statements = false;
    options.no_empty_function = false;
    options.typescript_eslint_no_empty_function = false;
    options.no_new = false;
    options.no_var = false;
    options.no_unused_expressions = false;
    options.typescript_eslint_no_unused_expressions = false;
    options.no_unused_vars = false;
    options.vars_on_top = false;
    options.typescript_eslint_no_use_before_define = false;
    options.parser_semantic_errors = false;

    const source =
        \\f();
        \\function f() {}
        \\new C();
        \\class C {}
        \\a;
        \\var a = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_use_before_define.id));
}

test "supports configured no-use-before-define nofunc style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"nofunc\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-use-before-define", config.value);
    options.eol_last = false;
    options.no_empty_block_statements = false;
    options.no_empty_function = false;
    options.typescript_eslint_no_empty_function = false;
    options.no_new = false;
    options.no_var = false;
    options.no_unused_expressions = false;
    options.typescript_eslint_no_unused_expressions = false;
    options.no_unused_vars = false;
    options.vars_on_top = false;
    options.typescript_eslint_no_use_before_define = false;
    options.parser_semantic_errors = false;

    const source =
        \\f();
        \\function f() {}
        \\new C();
        \\class C {}
        \\a;
        \\var a = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_use_before_define.id));
}

test "supports configured no-use-before-define variables false" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"functions\":false,\"classes\":false,\"variables\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-use-before-define", config.value);
    options.eol_last = false;
    options.no_empty_block_statements = false;
    options.no_empty_function = false;
    options.typescript_eslint_no_empty_function = false;
    options.no_unused_expressions = false;
    options.typescript_eslint_no_unused_expressions = false;
    options.no_unused_vars = false;
    options.typescript_eslint_no_use_before_define = false;
    options.parser_semantic_errors = false;

    const source =
        \\nested();
        \\function nested() {
        \\  outer;
        \\}
        \\var outer = 1;
        \\sameScope;
        \\var sameScope = 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_use_before_define.id));
}

test "supports configured no-use-before-define allowNamedExports" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowNamedExports\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-use-before-define", config.value);
    options.no_unused_expressions = false;
    options.typescript_eslint_no_unused_expressions = false;
    options.no_unused_vars = false;
    options.typescript_eslint_no_use_before_define = false;
    options.parser_semantic_errors = false;

    const source =
        \\export { allowed };
        \\reported;
        \\const allowed = 1;
        \\const reported = 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.mjs", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_use_before_define.id));
}

test "reports no-use-before-define named exports by default" {
    const source =
        \\export { reported };
        \\const reported = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.mjs", .{
        .no_unused_vars = false,
        .typescript_eslint_no_use_before_define = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_use_before_define.id));
}

test "can disable no-use-before-define" {
    const source =
        \\a;
        \\var a = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_use_before_define = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .typescript_eslint_no_use_before_define = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_use_before_define.id));
}
