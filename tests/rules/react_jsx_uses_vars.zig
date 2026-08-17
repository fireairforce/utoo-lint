const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "marks JSX component variables as used" {
    const source =
        \\const Component = () => null;
        \\export const node = <Component />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "JSX references remain semantic uses when react jsx uses vars is disabled" {
    const source =
        \\const Component = () => null;
        \\export const node = <Component />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .no_undef = false,
        .react_jsx_uses_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "both unused variable rules count JSX references in isolated rule configs" {
    const source =
        \\function Header() {
        \\  return <header>Utoo</header>;
        \\}
        \\
        \\export function App() {
        \\  return <Header />;
        \\}
    ;

    var eslint_options = lint.Options.allDisabled();
    eslint_options.no_unused_vars = true;
    var eslint_result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", eslint_options);
    defer eslint_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(eslint_result, lint.rules.no_unused_vars.id));

    var typescript_options = lint.Options.allDisabled();
    typescript_options.typescript_eslint_no_unused_vars = true;
    var typescript_result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", typescript_options);
    defer typescript_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(typescript_result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "component imports used only as JSX tags are not unused" {
    const source =
        \\import { Header } from "./Header";
        \\
        \\export function App() {
        \\  return <Header />;
        \\}
    ;

    var options = lint.Options.allDisabled();
    options.typescript_eslint_no_unused_vars = true;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "lowercase JSX member roots are variable references" {
    const source =
        \\import { motion } from "framer-motion";
        \\
        \\export function App() {
        \\  return <motion.div>Utoo</motion.div>;
        \\}
    ;

    var eslint_options = lint.Options.allDisabled();
    eslint_options.no_unused_vars = true;
    var eslint_result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", eslint_options);
    defer eslint_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(eslint_result, lint.rules.no_unused_vars.id));

    var typescript_options = lint.Options.allDisabled();
    typescript_options.typescript_eslint_no_unused_vars = true;
    var typescript_result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", typescript_options);
    defer typescript_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(typescript_result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "JSX member roots use the nearest lexical binding" {
    const source =
        \\import { motion } from "framer-motion";
        \\
        \\export function App() {
        \\  const motion = { div: () => null };
        \\  return <motion.div>Utoo</motion.div>;
        \\}
    ;

    var options = lint.Options.allDisabled();
    options.typescript_eslint_no_unused_vars = true;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(
        @as(usize, 1),
        helpers.countRule(result, lint.rules.typescript_eslint_no_unused_vars.id),
    );
}

test "does not treat lowercase DOM JSX as variable usage" {
    const source =
        \\const div = 1;
        \\export const node = <div />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}
