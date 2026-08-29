const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn count(source: []const u8, file_name: []const u8) !usize {
    var options = lint.Options.allDisabled();
    options.no_useless_assignment = true;
    var result = try lint.lintSource(std.testing.allocator, source, file_name, options);
    defer result.deinit(std.testing.allocator);
    return helpers.countRule(result, lint.rules.no_useless_assignment.id);
}

test "reports overwritten and final assignments" {
    try std.testing.expectEqual(@as(usize, 1), try count(
        "let value = 'used'; console.log(value); value = 'unused';",
        "fixture.js",
    ));
    try std.testing.expectEqual(@as(usize, 2), try count(
        "let value = 'used'; console.log(value); value = 1; value = 2;",
        "fixture.js",
    ));
}

test "reports assignments in source order" {
    var options = lint.Options.allDisabled();
    options.no_useless_assignment = true;
    var result = try lint.lintSource(
        std.testing.allocator,
        "function f() { let outer = 0; if (cond) { let inner = 0; console.log(inner); inner = 1; inner = 2; } console.log(outer); outer = 1; }",
        "fixture.js",
        options,
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), result.diagnostics.len);
    try std.testing.expect(result.diagnostics[0].span.start < result.diagnostics[1].span.start);
    try std.testing.expect(result.diagnostics[1].span.start < result.diagnostics[2].span.start);
}

test "tracks branches and abrupt completion" {
    try std.testing.expectEqual(@as(usize, 0), try count(
        "function f() { let value = 1; if (cond) { value = 2; console.log(value); return; } console.log(value); }",
        "fixture.js",
    ));
    try std.testing.expectEqual(@as(usize, 1), try count(
        "function f() { let value = 1; if (cond) { value = 2; return; } console.log(value); }",
        "fixture.js",
    ));
}

test "tracks loop-carried reads and updates" {
    try std.testing.expectEqual(@as(usize, 0), try count(
        "function f() { let value = 1; for (let i = 0; i < 10; i++) { console.log(value); value = 2; } }",
        "fixture.js",
    ));
    try std.testing.expectEqual(@as(usize, 1), try count(
        "function f() { let value = 1; console.log(value); value++; }",
        "fixture.js",
    ));
}

test "tracks destructuring and optional defaults" {
    try std.testing.expectEqual(@as(usize, 0), try count(
        "const obj = { a: 1 }; let { a, b = (a = 2) } = obj; console.log(a, b);",
        "fixture.js",
    ));
    try std.testing.expectEqual(@as(usize, 2), try count(
        "const obj = { a: 1 }; let { a, b = (a = 2) } = obj; a = 3; console.log(a, b);",
        "fixture.js",
    ));
    try std.testing.expectEqual(@as(usize, 1), try count(
        "function f() { let x = 0; console.log(x); const { a = (x = 1) } = {}; x = 2; console.log(x); }",
        "fixture.js",
    ));
    try std.testing.expectEqual(@as(usize, 0), try count(
        "function f() { let x = 1; const { a = x } = {}; x = 2; console.log(x); }",
        "fixture.js",
    ));
}

test "is conservative across try blocks and nested code paths" {
    try std.testing.expectEqual(@as(usize, 0), try count(
        "let message = 'init'; try { message = call(); } catch {} console.log(message);",
        "fixture.js",
    ));
    try std.testing.expectEqual(@as(usize, 0), try count(
        "function f() { let value = 1; setTimeout(() => console.log(value)); value = 2; }",
        "fixture.js",
    ));
}

test "skips exported bindings and variables without reads" {
    try std.testing.expectEqual(@as(usize, 0), try count(
        "let value = 1; export { value }; console.log(value); value = 2;",
        "fixture.js",
    ));
    try std.testing.expectEqual(@as(usize, 0), try count(
        "let unused = 1; unused = 2;",
        "fixture.js",
    ));
}

test "skips bindings named by exported directives" {
    try std.testing.expectEqual(@as(usize, 0), try count(
        "/* exported value, other */ let value = 1; console.log(value); value = 2;",
        "fixture.js",
    ));
}

test "counts JSX references as reads" {
    try std.testing.expectEqual(@as(usize, 1), try count(
        "function App() { let Component = 'unused'; Component = Used; return <Component />; }",
        "fixture.jsx",
    ));
}

test "uses the official message and is enabled by default" {
    var options = lint.Options.allDisabled();
    options.no_useless_assignment = true;
    var result = try lint.lintSource(
        std.testing.allocator,
        "let value = 1; console.log(value); value = 2;",
        "fixture.js",
        options,
    );
    defer result.deinit(std.testing.allocator);

    var saw_message = false;
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_useless_assignment.id) and
            std.mem.eql(u8, diagnostic.message, "This assigned value is not used in subsequent statements."))
        {
            try std.testing.expectEqualStrings("value", "let value = 1; console.log(value); value = 2;"[diagnostic.span.start..diagnostic.span.end]);
            saw_message = true;
        }
    }
    try std.testing.expect(saw_message);
    try std.testing.expect((lint.Options{}).no_useless_assignment);
}
