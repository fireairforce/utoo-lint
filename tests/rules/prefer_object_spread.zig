const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-object-spread for Object.assign into object literals" {
    const source =
        \\const first = Object.assign({}, source);
        \\const second = Object.assign({ value: 1 }, source, extra);
        \\const third = Object["assign"]({}, source);
        \\const fourth = Object[`assign`]({}, source);
        \\const fifth = Object?.assign({}, source);
        \\const sixth = Object?.["assign"]({}, source);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .dot_notation = false,
        .typescript_eslint_dot_notation = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.prefer_object_spread.id));
    try std.testing.expectEqualStrings("Use an object spread instead of Object.assign.", result.diagnostics[0].message);
}

test "autofixes Object.assign into an object spread" {
    const source = "const result = Object.assign({}, source);";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("const result = { ...source};", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_object_spread.id));
}

test "autofix merges object properties and parenthesizes spread operands" {
    const source = "Object.assign({ first: 1 }, extra, condition ? yes : no);";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("({first: 1, ...extra, ...(condition ? yes : no)});", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_object_spread.id));
}

test "autofixes single-argument Object.assign calls to object literals" {
    const source =
        \\Object.assign({ value: 1 });
        \\const empty = Object.assign({});
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        \\({value: 1});
        \\const empty = {};
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_object_spread.id));
}

test "autofix does not treat a comma in a comment as a trailing comma" {
    const source = "Object.assign({ first: 1 /* comma, in comment */ }, extra);";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("({first: 1 /* comma, in comment */, ...extra});", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_object_spread.id));
}

test "autofix preserves comments and trailing commas while merging object literals" {
    const source =
        \\const value = Object.assign({ first: 1, }, /* keep */ { second: 2 }, extra);
        \\const multiline = Object.assign({ first: 1 }, {
        \\  // keep this line
        \\  second: 2
        \\});
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        \\const value = {first: 1, /* keep */ second: 2, ...extra};
        \\const multiline = {first: 1, // keep this line
        \\  second: 2};
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_object_spread.id));
}

test "autofix preserves comments around parenthesized object arguments" {
    const source = "const value = Object.assign((/* before */ { first: 1 } /* after */), extra);";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        "const value = {/* before */ first: 1 /* after */, ...extra};",
        result.output,
    );
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_object_spread.id));
}

test "autofix handles TypeScript type arguments and expression contexts" {
    const source =
        \\const object = Object.assign<{}, Record<string, string[]>>({}, getObject());
        \\const array = [Object.assign({}, source)];
        \\function make() { return Object.assign({}, source); }
        \\consume(Object.assign({}, source));
        \\const arrow = () => Object.assign({}, source);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        \\const object = { ...getObject()};
        \\const array = [{ ...source}];
        \\function make() { return { ...source}; }
        \\consume({ ...source});
        \\const arrow = () => ({ ...source});
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_object_spread.id));
}

test "allows non-object targets shadowed Object and spread arguments" {
    const source =
        \\const target = {};
        \\Object.assign(target, source);
        \\Object.assign({}, ...sources);
        \\Object[assign]({}, source);
        \\Object[`assi${name}`]({}, source);
        \\Object?.[`assi${name}`]({}, source);
        \\function local(Object) {
        \\  Object.assign({}, source);
        \\}
        \\Object.assign({ get value() {} }, source);
        \\Object.assign({}, { set value(next) {} });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_object_spread.id));
}

test "can disable prefer-object-spread" {
    const source = "const value = Object.assign({}, source);\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .prefer_object_spread = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_object_spread.id));
}
