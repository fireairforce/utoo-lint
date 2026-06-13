const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-unnecessary-parameter-property-assignment for redundant constructor assignments" {
    const source =
        \\class User {
        \\  constructor(private name: string, readonly id = 1) {
        \\    this.name = name;
        \\    if (id) {
        \\      this.id = id;
        \\    }
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_empty_function = false,
        .typescript_eslint_no_inferrable_types = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_unnecessary_parameter_property_assignment.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_unnecessary_parameter_property_assignment.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "allows assignments that are not from the matching parameter property" {
    const source =
        \\class User {
        \\  constructor(private name: string, private id: number, value: string) {
        \\    this.name = value;
        \\    this.id = 2;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_empty_function = false,
        .typescript_eslint_no_inferrable_types = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unnecessary_parameter_property_assignment.id));
}

test "can disable @typescript-eslint/no-unnecessary-parameter-property-assignment" {
    const source =
        \\class User {
        \\  constructor(private name: string) {
        \\    this.name = name;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_empty_function = false,
        .typescript_eslint_no_inferrable_types = false,
        .typescript_eslint_no_unnecessary_parameter_property_assignment = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unnecessary_parameter_property_assignment.id));
}
