const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unused-vars for unused declarations" {
    const source =
        \\const unused = 1;
        \\const used = 2;
        \\console.log(used);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{});
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.no_unused_vars.id));
}
