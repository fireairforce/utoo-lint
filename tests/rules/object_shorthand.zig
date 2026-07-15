const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports object-shorthand for redundant property and method forms" {
    const source =
        \\const foo = 1;
        \\const obj = {
        \\  foo: foo,
        \\  bar: function () {
        \\    return 1;
        \\  },
        \\  asyncValue: async function () {
        \\    return 2;
        \\  },
        \\  "quoted": quoted,
        \\  "quoted-method": function () {
        \\    return 3;
        \\  },
        \\  [computedMethod]: function () {
        \\    return 4;
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "autofixes redundant object properties to shorthand" {
    const source =
        \\const foo = 1;
        \\const quoted = 2;
        \\const object = { foo: foo, "quoted": quoted };
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const foo = 1;
        \\const quoted = 2;
        \\const object = { foo, quoted };
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.object_shorthand.id));
}

test "autofixes anonymous functions to object methods" {
    const source =
        \\const object = {
        \\  plain: function () { return 1; },
        \\  asyncValue: async function () { return 2; },
        \\  generated: function* () { yield 3; },
        \\  [computed]: function (value) { return value; },
        \\};
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const object = {
        \\  plain() { return 1; },
        \\  async asyncValue() { return 2; },
        \\  *generated() { yield 3; },
        \\  [computed](value) { return value; },
        \\};
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.object_shorthand.id));
}

test "autofixes shorthand properties and methods to longform" {
    const source =
        \\const object = {
        \\  foo,
        \\  method(value) { return value; },
        \\  async asyncMethod() { return 1; },
        \\  *generated() { yield 2; },
        \\  [computed]() { return 3; },
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const object = {
        \\  foo: foo,
        \\  method: function(value) { return value; },
        \\  asyncMethod: async function() { return 1; },
        \\  generated: function*() { yield 2; },
        \\  [computed]: function() { return 3; },
        \\};
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.object_shorthand.id));
}

test "autofixes explicit-return arrows to object methods" {
    const source =
        \\const object = {
        \\  plain: value => { return value; },
        \\  noParams: () => { return 1; },
        \\  asyncValue: async (value) => { return value; },
        \\  generic: <T>(value: T): T => { return value; },
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"avoidExplicitReturnArrows\":true}]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const object = {
        \\  plain(value) { return value; },
        \\  noParams() { return 1; },
        \\  async asyncValue(value) { return value; },
        \\  generic<T>(value: T): T { return value; },
        \\};
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.object_shorthand.id));
}

test "autofixes without discarding comments or changing __proto__ semantics" {
    const source =
        \\const object = {
        \\  safe: safe,
        \\  preserved: function () { /* keep body */ return 1; },
        \\  commented: /* keep property */ commented,
        \\  commentedMethod: /* keep method */ function () { return 2; },
        \\  commentedArrow: /* keep arrow */ () => { return 3; },
        \\  __proto__: __proto__,
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"avoidExplicitReturnArrows\":true}]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .capitalized_comments = false,
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const object = {
        \\  safe,
        \\  preserved() { /* keep body */ return 1; },
        \\  commented: /* keep property */ commented,
        \\  commentedMethod: /* keep method */ function () { return 2; },
        \\  commentedArrow: /* keep arrow */ () => { return 3; },
        \\  __proto__: __proto__,
        \\};
    , result.output);
    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result.result, lint.rules.object_shorthand.id));
}

test "never mode does not create prototype setters or invalid super references" {
    const source =
        \\const object = {
        \\  safe,
        \\  __proto__,
        \\  inherited() { return super.value; },
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const object = {
        \\  safe: safe,
        \\  __proto__,
        \\  inherited() { return super.value; },
        \\};
    , result.output);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result.result, lint.rules.object_shorthand.id));
}

test "does not report object-shorthand for non-shorthandable properties" {
    const source =
        \\const foo = 1;
        \\const obj = {
        \\  foo,
        \\  foo: bar,
        \\  "foo": bar,
        \\  [foo]: foo,
        \\  method() {
        \\    return foo;
        \\  },
        \\  async asyncMethod() {
        \\    return foo;
        \\  },
        \\  bar: function named() {
        \\    return 1;
        \\  },
        \\  get value() {
        \\    return foo;
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.object_shorthand.id));
}

test "supports configured object-shorthand methods style" {
    const source =
        \\const obj = {
        \\  foo: foo,
        \\  bar: function () {
        \\    return 1;
        \\  },
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"methods\"]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "supports configured object-shorthand properties style" {
    const source =
        \\const obj = {
        \\  foo: foo,
        \\  bar: function () {
        \\    return 1;
        \\  },
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"properties\"]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "supports configured object-shorthand never style" {
    const source =
        \\const obj = {
        \\  foo,
        \\  bar() {
        \\    return 1;
        \\  },
        \\  baz: baz,
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "supports configured object-shorthand avoidQuotes option" {
    const source =
        \\const obj = {
        \\  foo: foo,
        \\  "quoted": quoted,
        \\  "quoted-method": function () {
        \\    return 1;
        \\  },
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"avoidQuotes\":true}]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "supports configured object-shorthand ignoreConstructors option" {
    const source =
        \\const obj = {
        \\  ConstructorFunction: function () {
        \\    return this.value;
        \\  },
        \\  $1_ConstructorFunction: function () {
        \\    return this.value;
        \\  },
        \\  ordinaryFunction: function () {
        \\    return 1;
        \\  },
        \\};
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer default_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(default_result, lint.rules.object_shorthand.id));

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"ignoreConstructors\":true}]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "supports configured object-shorthand avoidExplicitReturnArrows option" {
    const source =
        \\const obj = {
        \\  foo: () => {
        \\    return 1;
        \\  },
        \\  asyncFoo: async () => {
        \\    return foo;
        \\  },
        \\  value: value,
        \\  lexicalThis: () => {
        \\    return this.value;
        \\  },
        \\  lexicalArguments: () => {
        \\    return arguments[0];
        \\  },
        \\  expressionBody: () => value,
        \\  bareReturn: () => {
        \\    return;
        \\  },
        \\};
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer default_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.object_shorthand.id));

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"avoidExplicitReturnArrows\":true}]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "can disable object-shorthand" {
    const source =
        \\const obj = {
        \\  foo: foo,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .object_shorthand = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.object_shorthand.id));
}
