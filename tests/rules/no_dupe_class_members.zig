const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-dupe-class-members for duplicate methods and fields" {
    const source =
        \\class Example {
        \\  value() {}
        \\  value() {}
        \\  field = 1;
        \\  field = 2;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_dupe_class_members = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_dupe_class_members.id));
    try std.testing.expectEqualStrings("Duplicate class member.", result.diagnostics[0].message);
}

test "reports no-dupe-class-members for constructors and static members" {
    const source =
        \\class Example {
        \\  constructor() {}
        \\  constructor(value) {}
        \\  static value() {}
        \\  static value = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_dupe_class_members = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_dupe_class_members.id));
}

test "does not report no-dupe-class-members for allowed combinations" {
    const source =
        \\class Example {
        \\  get value() { return this.x; }
        \\  set value(next) { this.x = next; }
        \\  value2() {}
        \\  static value2() {}
        \\  [dynamic]() {}
        \\  dynamic() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_dupe_class_members = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_dupe_class_members.id));
}

test "can disable no-dupe-class-members" {
    const source =
        \\class Example {
        \\  value() {}
        \\  value() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_dupe_class_members = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_dupe_class_members = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_dupe_class_members.id));
}
