const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-proto for proto member access" {
    const source =
        \\obj.__proto__ = a;
        \\obj["__proto__"] = b;
        \\const c = obj.__proto__;
        \\const d = obj["__proto__"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.no_proto.id));
}

test "does not report no-proto for object literal proto property" {
    const source =
        \\const value = {
        \\  __proto__: null,
        \\  a: 1,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_proto.id));
}

test "can disable no-proto" {
    const source =
        \\const c = obj.__proto__;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_proto = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_proto.id));
}
