const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports global Function across TypeScript type positions" {
    const source =
        \\let annotation: Function;
        \\type Generic = Promise<Function>;
        \\type Union = Function | string;
        \\class ImplementsFunction implements Function {}
        \\interface ExtendsFunction extends Function {}
        \\export const View: Function = () => <div />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.typescript_eslint_no_unsafe_function_type.id));
}

test "allows explicit callable types and qualified names" {
    const source =
        \\let noArguments: () => void;
        \\let transform: <T>(value: T) => T;
        \\let generic: Promise<(value: string) => number>;
        \\type Qualified = globalThis.Function;
        \\interface Callable { (value: string): number }
        \\export const View: () => JSX.Element = () => <div />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unsafe_function_type.id));
}

test "allows user-defined type and value declarations named Function" {
    const source =
        \\{
        \\  type Function = () => void;
        \\  let localType: Function;
        \\}
        \\{
        \\  const Function = () => undefined;
        \\  let shadowedType: Function;
        \\  Function();
        \\}
        \\{
        \\  class Function {}
        \\  class Local implements Function {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unsafe_function_type.id));
}

test "allows imported Function type declarations" {
    const source =
        \\import type { Function } from "functions";
        \\let imported: Function;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unsafe_function_type.id));
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.typescript_eslint_no_unsafe_function_type = true;
    return options;
}
