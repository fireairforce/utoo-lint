const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-lone-blocks for unnecessary block statements" {
    const source =
        \\{
        \\  run();
        \\}
        \\if (ready) {
        \\  {
        \\    run();
        \\  }
        \\}
        \\function scoped() {
        \\  { let value = getValue(); }
        \\  { const value = getValue(); }
        \\  { class Scoped {} }
        \\  { function nested() {} }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.no_lone_blocks.id));
}

test "does not report no-lone-blocks for scoped declarations" {
    const source =
        \\{
        \\  let value = getValue();
        \\  use(value);
        \\}
        \\{
        \\  const value = getValue();
        \\  use(value);
        \\}
        \\{
        \\  class Scoped {}
        \\  use(Scoped);
        \\}
        \\{
        \\  function scoped() {}
        \\  use(scoped);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_lone_blocks.id));
}

test "does not report no-lone-blocks for structured statement bodies" {
    const source =
        \\if (ready) { run(); } else { stop(); }
        \\while (ready) { run(); }
        \\for (let i = 0; i < 1; i++) { run(); }
        \\switch (value) {
        \\  case 1:
        \\    {
        \\      run();
        \\    }
        \\}
        \\switch (value) {
        \\  default:
        \\    {
        \\      run();
        \\    }
        \\}
        \\try { run(); } catch (error) { handle(error); } finally { cleanup(); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_lone_blocks.id));
}

test "can disable no-lone-blocks" {
    const source =
        \\{
        \\  run();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_lone_blocks = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_lone_blocks.id));
}
