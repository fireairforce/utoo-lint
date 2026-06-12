const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-empty-interface for empty interfaces" {
    const source =
        \\interface Empty {}
        \\interface SingleExtends extends Base {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_empty_interface.id));
}

test "does not report @typescript-eslint/no-empty-interface for non-empty or multi-extends interfaces" {
    const source =
        \\interface WithMember {
        \\  value: string;
        \\}
        \\interface MultiExtends extends Base, Other {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_empty_interface.id));
}

test "can disable @typescript-eslint/no-empty-interface" {
    const source =
        \\interface Empty {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_empty_interface = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_empty_interface.id));
}
