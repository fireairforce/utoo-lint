const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports instance methods accessors and function-valued fields without this" {
    const source =
        \\class Example {
        \\  method() {}
        \\  get value() { return 1; }
        \\  set value(next) { consume(next); }
        \\  field = () => {};
        \\  privateField = function () {};
        \\  wrappedField = (() => {});
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .class_methods_use_this = true,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.class_methods_use_this.id));
    try std.testing.expectEqualStrings("Expected 'this' to be used by class method 'method'.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Expected 'this' to be used by class getter 'value'.", ruleDiagnostic(result, 1).message);
    try std.testing.expectEqualStrings("Expected 'this' to be used by class setter 'value'.", ruleDiagnostic(result, 2).message);
}

test "allows constructors static members and direct this or super usage" {
    const source =
        \\class Example extends Base {
        \\  constructor() {}
        \\  static utility() {}
        \\  method() { return this.value; }
        \\  inherited() { return super.value; }
        \\  arrow() { return () => this.value; }
        \\  field = () => this.value;
        \\  functionField = function () { return this.value; };
        \\  static staticField = () => {};
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .class_methods_use_this = true,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.class_methods_use_this.id));
}

test "isolates nested functions class fields and static blocks" {
    const source =
        \\class Example {
        \\  nestedFunction() { function inner() { return this.value; } }
        \\  nestedField() { return class Inner { field = this.value; }; }
        \\  nestedStaticBlock() { return class Inner { static { this.value; } }; }
        \\  computedField() { return class Inner { [this.key] = 1; }; }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .class_methods_use_this = true,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.class_methods_use_this.id));
}

test "supports exceptions field enforcement and override options" {
    const source =
        \\class Example extends Base {
        \\  kept() {}
        \\  field = () => {};
        \\  override inherited() {}
        \\}
    ;

    var options = lint.Options{
        .class_methods_use_this = true,
        .class_methods_use_this_enforce_for_class_fields = false,
        .class_methods_use_this_ignore_override_methods = true,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.class_methods_use_this_except_methods.append("kept");
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.class_methods_use_this.id));
}

test "supports implements exclusions for all and public members" {
    const source =
        \\interface Contract {}
        \\class Example implements Contract {
        \\  public exposed() {}
        \\  protected inherited() {}
        \\  private internal() {}
        \\  #secret() {}
        \\}
    ;

    var public_result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .class_methods_use_this = true,
        .class_methods_use_this_ignore_classes_with_implements = .public_fields,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer public_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(public_result, lint.rules.class_methods_use_this.id));

    var all_result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .class_methods_use_this = true,
        .class_methods_use_this_ignore_classes_with_implements = .all,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer all_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(all_result, lint.rules.class_methods_use_this.id));
}

test "reports private and computed methods with ESLint-compatible descriptions" {
    const source =
        \\class Example {
        \\  #secret() {}
        \\  [dynamic]() {}
        \\  *generator() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .class_methods_use_this = true,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("Expected 'this' to be used by class private method #secret.", ruleDiagnostic(result, 0).message);
    try std.testing.expectEqualStrings("Expected 'this' to be used by class method.", ruleDiagnostic(result, 1).message);
    try std.testing.expectEqualStrings("Expected 'this' to be used by class generator method 'generator'.", ruleDiagnostic(result, 2).message);
}

test "can disable class-methods-use-this" {
    var result = try lint.lintSource(std.testing.allocator, "class Example { method() {} }", "fixture.js", .{
        .class_methods_use_this = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.class_methods_use_this.id));
}

fn ruleDiagnostic(result: lint.Result, ordinal: usize) lint.Diagnostic {
    var seen: usize = 0;
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.class_methods_use_this.id)) continue;
        if (seen == ordinal) return diagnostic;
        seen += 1;
    }
    unreachable;
}
