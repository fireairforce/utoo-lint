const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-exponentiation-operator for Math.pow calls" {
    const source =
        \\Math.pow(base, exponent);
        \\Math.pow();
        \\Math.pow(base);
        \\Math.pow(base, exponent, modulo);
        \\(Math).pow(2, 8);
        \\Math["pow"](2, 8);
        \\Math[`pow`](2, 8);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.prefer_exponentiation_operator.id));
    try std.testing.expectEqualStrings(
        "Use the exponentiation operator (**) instead of Math.pow.",
        result.diagnostics[0].message,
    );
}

test "autofixes a two-argument Math.pow call" {
    const source = "const result = Math.pow(base, exponent);";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("const result = base**exponent;", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "does not autofix calls with unsafe arguments or comments" {
    const source =
        \\Math.pow();
        \\Math.pow(base);
        \\Math.pow(base, exponent, modulus);
        \\Math.pow(...values);
        \\Math.pow(base, ...values);
        \\Math/**/.pow(base, exponent);
        \\Math.pow(base, /* keep */ exponent);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(
        @as(usize, 7),
        helpers.countRule(result.result, lint.rules.prefer_exponentiation_operator.id),
    );
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.prefer_exponentiation_operator.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "preserves outside comments and removes redundant operand parentheses" {
    const source = "/* before */Math.pow(((base)), ((exponent)))/* after */;";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("/* before */base**exponent/* after */;", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "parenthesizes Math.pow operands according to exponentiation precedence" {
    const source =
        \\Math.pow(a + b, c + d);
        \\Math.pow(a ** b, c);
        \\Math.pow(a, b ** c);
        \\Math.pow(-a, -b);
        \\Math.pow(a = b, c = d);
        \\Math.pow((a, b), (c, d));
        \\Math.pow(() => a, () => b);
        \\async function run() { return Math.pow(await a, await b); }
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\(a + b)**(c + d);
        \\(a ** b)**c;
        \\a**b ** c;
        \\(-a)**-b;
        \\(a = b)**(c = d);
        \\(a, b)**(c, d);
        \\(() => a)**(() => b);
        \\async function run() { return (await a)**await b; }
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "parenthesizes exponentiation when required by its surrounding expression" {
    const source =
        \\+Math.pow(a, b);
        \\Math.pow(a, b).toString();
        \\Math.pow(a, b)();
        \\Math.pow(a, b) ** c;
        \\a ** Math.pow(b, c);
        \\consume(Math.pow(a, b));
        \\object[Math.pow(a, b)];
        \\[Math.pow(a, b)];
        \\class C extends Math.pow(a, b) {}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\+(a**b);
        \\(a**b).toString();
        \\(a**b)();
        \\(a**b) ** c;
        \\a ** b**c;
        \\consume(a**b);
        \\object[a**b];
        \\[a**b];
        \\class C extends (a**b) {}
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "keeps replacement tokens lexically separated from their neighbors" {
    const source =
        \\a+Math.pow(++b, c);
        \\a-Math.pow(--b, c);
        \\Math.pow(a, b)in object;
        \\a/Math.pow(/value/, 2);
        \\a*Math.pow(/value/, 2);
        \\Math.pow(a, /value/)/divisor;
        \\a+/**/Math.pow(++b, c)/**/in object;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\a+ ++b**c;
        \\a- --b**c;
        \\a**b in object;
        \\a/ /value/**2;
        \\a* /value/**2;
        \\a**/value/ /divisor;
        \\a+/**/++b**c/**/in object;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "preserves expression statement parsing and automatic semicolon insertion" {
    const source =
        \\Math.pow({ value: 2 }.value, 3);
        \\Math.pow(function () { return 2; }(), 3);
        \\Math.pow(class { static value = 2 }.value, 3);
        \\first
        \\Math.pow(a + b, c);
        \\second
        \\Math.pow([a, b].length, c);
        \\third
        \\Math.pow(/regex/.source.length, c);
        \\fourth
        \\Math.pow(`value`.length, c);
        \\done;
        \\Math.pow((a).value, c);
        \\if (done) {}
        \\Math.pow((b).value, c);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
        .wrap_iife = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\({ value: 2 }.value**3);
        \\(function () { return 2; }()**3);
        \\(class { static value = 2 }.value**3);
        \\first
        \\;(a + b)**c;
        \\second
        \\;[a, b].length**c;
        \\third
        \\;/regex/.source.length**c;
        \\fourth
        \\;`value`.length**c;
        \\done;
        \\(a).value**c;
        \\if (done) {}
        \\(b).value**c;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "does not insert a semicolon before a control-flow body" {
    const source =
        \\if (condition)
        \\  Math.pow([a].length, b);
        \\while (condition)
        \\  Math.pow([a].length, b);
        \\for (; condition;)
        \\  Math.pow([a].length, b);
        \\label:
        \\  Math.pow([a].length, b);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .eol_last = false,
        .no_extra_label = false,
        .no_undef = false,
        .no_unused_labels = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\if (condition)
        \\  [a].length**b;
        \\while (condition)
        \\  [a].length**b;
        \\for (; condition;)
        \\  [a].length**b;
        \\label:
        \\  [a].length**b;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "autofixes parenthesized computed and optional Math.pow calls" {
    const source =
        \\(Math).pow(2, 8);
        \\Math["pow"](2, 8);
        \\Math[`pow`](2, 8);
        \\Math.pow?.(2, 8);
        \\Math?.pow(2, 8);
        \\Math?.pow?.(2, 8);
        \\(Math?.pow)?.(2, 8);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .typescript_eslint_dot_notation = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\2**8;
        \\2**8;
        \\2**8;
        \\2**8;
        \\2**8;
        \\2**8;
        \\2**8;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "parenthesizes TypeScript assertions in operand and parent positions" {
    const source =
        \\const first = Math.pow(base as number, exponent);
        \\const second = Math.pow(base, exponent as number);
        \\const third = Math.pow(base, exponent) as number;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const first = (base as number)**exponent;
        \\const second = base**(exponent as number);
        \\const third = (base**exponent) as number;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "autofixes nested Math.pow calls across fix iterations" {
    const source = "Math.pow(Math.pow(a, b), Math.pow(c, d));";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("(a**b)**c**d;", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "inserts a semicolon after brace-ending expression statements" {
    const source =
        \\let previous = function () {}
        \\Math.pow(a + b, c);
        \\previous = {}
        \\Math.pow([a].length, c);
        \\previous = class {}
        \\Math.pow(`value`.length, c);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\let previous = function () {}
        \\;(a + b)**c;
        \\previous = {}
        \\;[a].length**c;
        \\previous = class {}
        \\;`value`.length**c;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "does not insert a semicolon after an uninitialized declaration" {
    const source =
        \\let previous
        \\Math.pow([a].length, b);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\let previous
        \\[a].length**b;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "does not insert a semicolon after a module declaration" {
    const source =
        \\import "first"
        \\Math.pow([a].length, b);
        \\export * from "second"
        \\Math.pow([a].length, b);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.mjs", .{
        .eol_last = false,
        .no_undef = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\import "first"
        \\[a].length**b;
        \\export * from "second"
        \\[a].length**b;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "does not insert a semicolon after a TypeScript type boundary" {
    const source =
        \\type Value = number
        \\Math.pow([a].length, b);
        \\declare function consume(value: Value): void
        \\Math.pow([a].length, b);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\type Value = number
        \\[a].length**b;
        \\declare function consume(value: Value): void
        \\[a].length**b;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_exponentiation_operator.id));
}

test "does not report prefer-exponentiation-operator for other calls or shadowed Math" {
    const source =
        \\Math.max(base, exponent);
        \\Math[`po${letter}`](base, exponent);
        \\const Math = { pow() {} };
        \\Math.pow(base, exponent);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_exponentiation_operator.id));
}

test "can disable prefer-exponentiation-operator" {
    const source =
        \\Math.pow(base, exponent);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .prefer_exponentiation_operator = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_exponentiation_operator.id));
}
