const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unused-private-class-members for unused private fields and methods" {
    const source =
        \\class Example {
        \\  #field = 1;
        \\  #method() {}
        \\  static #staticField = 1;
        \\  static #staticMethod() {}
        \\  run() {
        \\    return 1;
        \\  }
        \\}
        \\
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_unused_private_class_members.id));
    try std.testing.expectEqualStrings("Private class member is defined but never used.", result.diagnostics[0].message);
}

test "allows no-unused-private-class-members for read private members" {
    const source =
        \\class Example {
        \\  #field = 1;
        \\  #method() {
        \\    return this.#field;
        \\  }
        \\  static #staticField = 1;
        \\  static #staticMethod() {
        \\    return Example.#staticField;
        \\  }
        \\  run() {
        \\    return this.#method() + Example.#staticMethod();
        \\  }
        \\}
        \\
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unused_private_class_members.id));
}

test "does not treat pure private field writes as reads" {
    const source =
        \\class Example {
        \\  #field;
        \\  #compound = 1;
        \\  constructor() {
        \\    this.#field = 1;
        \\    this.#compound += 1;
        \\  }
        \\}
        \\
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unused_private_class_members.id));
}

test "counts private setter and accessor writes as usage" {
    const source =
        \\class Example {
        \\  set #value(next) {}
        \\  accessor #state = 1;
        \\  run() {
        \\    this.#value = 1;
        \\    this.#state = 2;
        \\  }
        \\}
        \\
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unused_private_class_members.id));
}

test "does not leak no-unused-private-class-members across nested classes" {
    const source =
        \\class Outer {
        \\  #outer = 1;
        \\  run() {
        \\    class Inner {
        \\      #outer = 2;
        \\      read(inner) {
        \\        return inner.#outer;
        \\      }
        \\    }
        \\    return Inner;
        \\  }
        \\}
        \\
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unused_private_class_members.id));
}

test "can disable no-unused-private-class-members" {
    const source =
        \\class Example {
        \\  #field = 1;
        \\}
        \\
    ;

    var options = baseOptions();
    options.no_unused_private_class_members = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unused_private_class_members.id));
}

fn baseOptions() lint.Options {
    return .{
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}
