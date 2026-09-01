const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports conditional expects with useful locations" {
    const source =
        \\test("conditions", () => {
        \\  if (first) {
        \\    if (second) expect(value).toBe(1);
        \\  }
        \\  switch (kind) {
        \\    case "value": expect(value).toBe(2); break;
        \\  }
        \\  ready ? expect(value).toBe(3) : noop();
        \\  enabled && expect(value).toBe(4);
        \\});
        \\it.each``("tagged", () => {
        \\  enabled || expect(value).toBe(5);
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.jest_no_conditional_expect.id));
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.jest_no_conditional_expect.id)) continue;
        const reported = source[diagnostic.span.start..diagnostic.span.end];
        try std.testing.expect(std.mem.startsWith(u8, reported, "expect("));
        try std.testing.expectEqualStrings("Avoid calling `expect` conditionally.", diagnostic.message);
    }
}

test "reports catch clauses and Promise catch callbacks" {
    const catch_source =
        \\it("catches", () => {
        \\  try {
        \\    work();
        \\  } catch (error) {
        \\    expect(error).toBeDefined();
        \\  }
        \\});
    ;
    var catch_result = try lint.lintSource(std.testing.allocator, catch_source, "fixture.js", optionsOnly());
    defer catch_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(catch_result, lint.rules.jest_no_conditional_expect.id));

    const promise_source =
        \\Promise.resolve()
        \\  .catch(error => expect(error).toBeDefined())
        \\  .catch(error => expect(error).toBeDefined())
        \\  .catch(error => expect(error).toBeDefined());
    ;
    var promise_result = try lint.lintSource(std.testing.allocator, promise_source, "fixture.js", optionsOnly());
    defer promise_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(promise_result, lint.rules.jest_no_conditional_expect.id));

    const overlapping_source =
        \\test("overlap", () => {
        \\  Promise.reject().catch(error => {
        \\    if (error) expect(error).toBeDefined();
        \\  });
        \\});
    ;
    var overlapping_result = try lint.lintSource(std.testing.allocator, overlapping_source, "fixture.js", optionsOnly());
    defer overlapping_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(overlapping_result, lint.rules.jest_no_conditional_expect.id));
}

test "reports named test callbacks without confusing same-name bindings" {
    const source =
        \\function declaredCallback() {
        \\  if (enabled) expect(value).toBe(1);
        \\}
        \\const arrowCallback = () => {
        \\  enabled && expect(value).toBe(2);
        \\};
        \\function unrelated() {
        \\  if (enabled) expect(value).toBe(3);
        \\}
        \\it("declared", declaredCallback);
        \\test.each([[1]])("arrow", arrowCallback);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.jest_no_conditional_expect.id));
}

test "allows unconditional expects and conditions that do not contain expects" {
    const source =
        \\test("valid", async () => {
        \\  if (enabled) value = 1;
        \\  const next = enabled ? 1 : 2;
        \\  enabled && update();
        \\  try {
        \\    await work();
        \\  } catch (error) {
        \\    recover(error);
        \\  } finally {
        \\    expect(value).toBe(next);
        \\  }
        \\  await work().catch(error => error);
        \\  expect(value).toBeDefined();
        \\});
        \\if (outside) expect(value).toBeDefined();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jest_no_conditional_expect.id));
}

test "supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "test('js', () => { if (ok) expect(value); });", .file_name = "fixture.js" },
        .{ .source = "test('ts', () => { const ok: boolean = true; if (ok) expect(value); });", .file_name = "fixture.ts" },
        .{ .source = "test('jsx', () => { if (ok) expect(<div />); });", .file_name = "fixture.jsx" },
        .{ .source = "test('tsx', () => { const node: JSX.Element = <div />; if (ok) expect(node); });", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.jest_no_conditional_expect.id));
    }
}

test "parses config and can disable jest/no-conditional-expect" {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "\"error\"", .{});
    defer parsed.deinit();

    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("jest/no-conditional-expect", parsed.value);
    try std.testing.expect(options.jest_no_conditional_expect);

    options.jest_no_conditional_expect = false;
    var result = try lint.lintSource(
        std.testing.allocator,
        "test('disabled', () => { if (ok) expect(value); });",
        "fixture.js",
        options,
    );
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.jest_no_conditional_expect.id));
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_no_conditional_expect = true;
    return options;
}
