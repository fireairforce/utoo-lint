const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-this-before-super before derived constructor super calls" {
    const source =
        \\class UsesThis extends Base {
        \\  constructor() {
        \\    this.value = 1;
        \\    super();
        \\  }
        \\}
        \\class UsesSuperProperty extends Base {
        \\  constructor() {
        \\    super.method();
        \\    super();
        \\  }
        \\}
        \\class Conditional extends Base {
        \\  constructor(flag) {
        \\    if (flag) {
        \\      super();
        \\    }
        \\    this.value = 1;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .constructor_super = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_this_before_super.id));
}

test "does not report no-this-before-super after guaranteed super calls" {
    const source =
        \\class Direct extends Base {
        \\  constructor() {
        \\    super();
        \\    this.value = 1;
        \\  }
        \\}
        \\class Branches extends Base {
        \\  constructor(flag) {
        \\    if (flag) {
        \\      super();
        \\    } else {
        \\      super();
        \\    }
        \\    this.value = 1;
        \\  }
        \\}
        \\class ReturnBranch extends Base {
        \\  constructor(flag) {
        \\    if (flag) {
        \\      return {};
        \\    }
        \\    super();
        \\    this.value = 1;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .constructor_super = false,
        .no_constructor_return = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_this_before_super.id));
}

test "ignores nested functions and base classes" {
    const source =
        \\class Derived extends Base {
        \\  constructor() {
        \\    const read = () => this.value;
        \\    function nested() {
        \\      return this.value;
        \\    }
        \\    super();
        \\  }
        \\}
        \\class BaseOnly {
        \\  constructor() {
        \\    this.value = 1;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_this_before_super.id));
}

test "can disable no-this-before-super" {
    const source =
        \\class Derived extends Base {
        \\  constructor() {
        \\    this.value = 1;
        \\    super();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_this_before_super = false,
        .constructor_super = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_this_before_super.id));
}
