const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-computed-key for object and pattern literal keys" {
    const source =
        \\const object = {
        \\  ["name"]: value,
        \\  [0]: value,
        \\  ["method"]() {},
        \\};
        \\const { ["name"]: name, [0]: zero } = object;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_useless_computed_key.id));
}

test "autofixes literal computed keys in objects, patterns, and classes" {
    const source =
        \\const object = {
        \\  ["name"]: value,
        \\  [0]: value,
        \\  ["method"]() {},
        \\};
        \\const { ["name"]: name, [0]: zero } = object;
        \\class Example {
        \\  ["method"]() {}
        \\  get ["value"]() {
        \\    return value;
        \\  }
        \\  ["field"] = value;
        \\  static ["name"]() {}
        \\}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_useless_rename = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const object = {
        \\  "name": value,
        \\  0: value,
        \\  "method"() {},
        \\};
        \\const { "name": name, 0: zero } = object;
        \\class Example {
        \\  "method"() {}
        \\  get "value"() {
        \\    return value;
        \\  }
        \\  "field" = value;
        \\  static "name"() {}
        \\}
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_useless_computed_key.id));
}

test "autofixes safe computed keys without discarding comments or merging numeric keys" {
    const source =
        \\const object = {
        \\  [ "spaced" ]: value,
        \\  [/* keep */ "before"]: value,
        \\  ["after" /* keep */]: value,
        \\  get[2]() {
        \\    return value;
        \\  },
        \\  get[.2]() {
        \\    return value;
        \\  },
        \\};
        \\class Example {
        \\  static[3] = value;
        \\}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_floating_decimal = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const object = {
        \\  "spaced": value,
        \\  [/* keep */ "before"]: value,
        \\  ["after" /* keep */]: value,
        \\  get 2() {
        \\    return value;
        \\  },
        \\  get.2() {
        \\    return value;
        \\  },
        \\};
        \\class Example {
        \\  static 3 = value;
        \\}
    , result.output);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result.result, lint.rules.no_useless_computed_key.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_useless_computed_key.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "reports no-useless-computed-key for class members with literal keys" {
    const source =
        \\class Example {
        \\  ["method"]() {}
        \\  get ["value"]() {
        \\    return value;
        \\  }
        \\  ["field"] = value;
        \\  static ["name"]() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_useless_computed_key.id));
}

test "allows class member computed keys when enforcement is disabled" {
    const source =
        \\const object = {
        \\  ["name"]: value,
        \\};
        \\class Example {
        \\  ["method"]() {}
        \\  ["field"] = value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_computed_key_enforce_for_class_members = .no,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_useless_computed_key.id));
}

test "does not report no-useless-computed-key for dynamic keys or semantic exceptions" {
    const source =
        \\const object = {
        \\  [name]: value,
        \\  ["__proto__"]: value,
        \\};
        \\const { [name]: local } = object;
        \\class Example {
        \\  ["constructor"]() {}
        \\  static ["prototype"]() {}
        \\  ["constructor"];
        \\  static ["constructor"];
        \\  static ["prototype"];
        \\  [name]() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_computed_key.id));
}

test "can disable no-useless-computed-key" {
    const source =
        \\const object = {
        \\  ["name"]: value,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_computed_key = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_computed_key.id));
}
