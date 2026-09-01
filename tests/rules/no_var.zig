const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-var for var declarations" {
    const source =
        \\var value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.no_var.id));
}

test "autofixes safe declarations to let without prefer-const" {
    const source =
        \\function increment() {
        \\  var value = 1;
        \\  value += 1;
        \\  var recursive = function () { return recursive; };
        \\  recursive();
        \\  return value;
        \\}
    ;
    const expected =
        \\function increment() {
        \\  let value = 1;
        \\  value += 1;
        \\  let recursive = function () { return recursive; };
        \\  recursive();
        \\  return value;
        \\}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options(false));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_var.id));
}

test "multi-pass autofix uses const when prefer-const allows it" {
    const source =
        \\function read() {
        \\  var value = 1;
        \\  return value;
        \\}
    ;
    const expected =
        \\function read() {
        \\  const value = 1;
        \\  return value;
        \\}
    ;

    var first = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options(true));
    defer first.deinit(std.testing.allocator);

    try std.testing.expect(first.fixed);
    try std.testing.expect(first.passes >= 2);
    try std.testing.expectEqualStrings(expected, first.output);

    var second = try lint.lintSourceAndFix(std.testing.allocator, first.output, "fixture.js", options(true));
    defer second.deinit(std.testing.allocator);
    try std.testing.expect(!second.fixed);
    try std.testing.expectEqualStrings(expected, second.output);
}

test "autofixes multiple declarators and loop declarations safely" {
    const source =
        \\function run(items) {
        \\  var first = 1, second = 2;
        \\  second += first;
        \\  for (var index = 0; index < items.length; index++) consume(items[index]);
        \\  for (var item of items) consume(item);
        \\}
    ;
    const expected =
        \\function run(items) {
        \\  let first = 1, second = 2;
        \\  second += first;
        \\  for (let index = 0; index < items.length; index++) consume(items[index]);
        \\  for (let item of items) consume(item);
        \\}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options(false));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_var.id));
}

test "finds the var keyword after TypeScript modifiers and comments" {
    const source = "declare /* var marker */ var value: number;";
    const expected = "declare /* var marker */ let value: number;";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.ts", options(false));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_var.id));
}

test "ignores var declarations in TypeScript global augmentation" {
    const source =
        \\export {};
        \\declare global {
        \\  var globalValue: number;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options(false));
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_var.id));
}

test "does not autofix declarations whose scope semantics could change" {
    const cases = [_]struct { source: []const u8, path: []const u8 }{
        .{
            .source =
            \\function escaped(ready) {
            \\  if (ready) { var value = 1; }
            \\  return value;
            \\}
            ,
            .path = "fixture.js",
        },
        .{
            .source =
            \\function redeclared() {
            \\  var value = 1;
            \\  var value = 2;
            \\  return value;
            \\}
            ,
            .path = "fixture.js",
        },
        .{
            .source =
            \\function hoisted() {
            \\  consume(value);
            \\  var value = 1;
            \\}
            ,
            .path = "fixture.js",
        },
        .{
            .source =
            \\function closures() {
            \\  const callbacks = [];
            \\  for (var index = 0; index < 2; index++) callbacks.push(() => index);
            \\  return callbacks;
            \\}
            ,
            .path = "fixture.js",
        },
        .{
            .source =
            \\function retained(ready) {
            \\  while (ready) {
            \\    var value;
            \\    consume(value);
            \\    value = 1;
            \\  }
            \\}
            ,
            .path = "fixture.js",
        },
        .{
            .source =
            \\function selfReference() {
            \\  var value = value;
            \\  return value;
            \\}
            ,
            .path = "fixture.js",
        },
        .{
            .source =
            \\function immediateSelfReference() {
            \\  var value = (() => value)();
            \\  return value;
            \\}
            ,
            .path = "fixture.js",
        },
        .{
            .source =
            \\function laterDeclarator() {
            \\  var first = second, second = 1;
            \\  return first;
            \\}
            ,
            .path = "fixture.js",
        },
        .{
            .source =
            \\function destructuringDefault(source) {
            \\  var { value = value } = source;
            \\  return value;
            \\}
            ,
            .path = "fixture.js",
        },
        .{
            .source = "var globalValue = 1;",
            .path = "fixture.cjs",
        },
        .{
            .source = "if (ready) var statementValue = 1;",
            .path = "fixture.js",
        },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.path, options(false));
        defer result.deinit(std.testing.allocator);

        try std.testing.expect(helpers.hasRule(result, lint.rules.no_var.id));
        for (result.diagnostics) |diagnostic| {
            if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_var.id)) {
                try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
            }
        }
    }
}

fn options(prefer_const: bool) lint.Options {
    return .{
        .capitalized_comments = false,
        .curly = false,
        .eol_last = false,
        .no_console = false,
        .no_plusplus = false,
        .no_undef = false,
        .no_unused_vars = false,
        .one_var = false,
        .prefer_const = prefer_const,
        .parser_semantic_errors = false,
    };
}
