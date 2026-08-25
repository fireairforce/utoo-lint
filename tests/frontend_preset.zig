const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("helpers.zig");

const frontend_config_path = "npm/utoo-lint/configs/frontend.json";

test "frontend preset reports React correctness and safety guardrails once" {
    const source =
        \\import { forwardRef, useEffect } from "react";
        \\const Widget = () => <span />;
        \\const Legacy = forwardRef((props, ref) => <div data-value={props.value} ref={ref} />);
        \\export function Screen({ items, html }) {
        \\  if (items.length > 0) {
        \\    useEffect(() => {}, []);
        \\  }
        \\  useEffect(() => {
        \\    console.log(items.length);
        \\  }, []);
        \\  const Nested = () => <strong />;
        \\  return <>
        \\    <a href="javascript:alert('x')">unsafe</a>
        \\    <Widget children={<span />} />
        \\    <img>child</img>
        \\    {items.map((item) => <Widget />)}
        \\    {items.map((item, index) => <Widget key={index} />)}
        \\    <div dangerouslySetInnerHTML={{ __html: html }}>child</div>
        \\    <Nested />
        \\    <Legacy value={items.length} />
        \\  </>;
        \\}
        \\export function nestedPromise() {
        \\  return Promise.resolve().then(() => Promise.resolve().then(() => 1));
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "frontend.tsx", try frontendOptions());
    defer result.deinit(std.testing.allocator);

    const expected_once = [_][]const u8{
        "react-hooks/rules-of-hooks",
        "react-hooks/exhaustive-deps",
        "react/jsx-key",
        "react/no-array-index-key",
        "react/no-children-prop",
        "react/no-danger",
        "react/no-danger-with-children",
        "react/void-dom-elements-no-children",
        "react/no-unstable-nested-components",
        "react/no-forward-ref",
        "no-script-url",
        "promise/no-nesting",
    };
    for (expected_once) |rule_id| {
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
}

test "frontend preset separates unused imports values and banned types" {
    const source =
        \\import type { UnusedImport } from "./types";
        \\type Broad = Object;
        \\const unusedValue = 1;
        \\export type Result = Broad;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "frontend.ts", try frontendOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, "unused-imports/no-unused-imports"));
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, "@typescript-eslint/no-unused-vars"));
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, "@typescript-eslint/ban-types"));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "no-unused-vars"));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
}

fn frontendOptions() !lint.Options {
    const frontend_config = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        frontend_config_path,
        std.testing.allocator,
        .limited(64 * 1024),
    );
    defer std.testing.allocator.free(frontend_config);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, frontend_config, .{});
    defer parsed.deinit();

    const root = switch (parsed.value) {
        .object => |object| object,
        else => return error.TestUnexpectedResult,
    };
    const rules = switch (root.get("rules") orelse return error.TestUnexpectedResult) {
        .object => |object| object,
        else => return error.TestUnexpectedResult,
    };

    var options = lint.Options.allDisabled();
    var iterator = rules.iterator();
    while (iterator.next()) |entry| {
        try options.setByRuleConfigValue(entry.key_ptr.*, entry.value_ptr.*);
    }
    return options;
}
