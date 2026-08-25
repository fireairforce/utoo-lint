const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.react_no_forward_ref.id;

test "reports named aliased default and namespace React imports" {
    const source =
        \\import React, { forwardRef, forwardRef as withRef } from "react";
        \\import * as ReactNS from "react";
        \\const One = forwardRef((props, ref) => <div ref={ref} />);
        \\const Two = withRef((props, ref) => <span ref={ref} />);
        \\const Three = React.forwardRef((props, ref) => <main ref={ref} />);
        \\const Four = ReactNS["forwardRef"]((props, ref) => <article ref={ref} />);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, rule_id));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.warning, diagnostic.severity);
    try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
}

test "does not report unrelated functions methods imports or type-only imports" {
    const source =
        \\import { forwardRef as otherForwardRef } from "other-library";
        \\import type { forwardRef as ForwardRefType } from "react";
        \\function forwardRef(value) { return value; }
        \\const React = { forwardRef(value) { return value; } };
        \\const api = { forwardRef(value) { return value; } };
        \\forwardRef(() => null);
        \\otherForwardRef(() => null);
        \\React.forwardRef(() => null);
        \\api.forwardRef(() => null);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, rule_id));
    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
}

test "respects local shadowing of a React import" {
    const source =
        \\import { forwardRef } from "react";
        \\function configure(forwardRef) {
        \\  return forwardRef(() => null);
        \\}
        \\const Component = forwardRef(() => null);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
}

test "is opt-in and accepted by CLI and project configuration" {
    try std.testing.expect(!(lint.Options{}).react_no_forward_ref);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.react_no_forward_ref);

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"warn\"]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue(rule_id, config.value);
    try std.testing.expect(options.react_no_forward_ref);
}

test "parses JS TS JSX and TSX cases without parser diagnostics" {
    const Fixture = struct {
        path: []const u8,
        source: []const u8,
    };
    const fixtures = [_]Fixture{
        .{
            .path = "fixture.js",
            .source =
            \\import { forwardRef } from "react";
            \\const Component = forwardRef(function Component(props, ref) { return null; });
            ,
        },
        .{
            .path = "fixture.jsx",
            .source =
            \\import { forwardRef as withRef } from "react";
            \\const Component = withRef((props, ref) => <div ref={ref} />);
            ,
        },
        .{
            .path = "fixture.ts",
            .source =
            \\import * as React from "react";
            \\const Component = React.forwardRef<HTMLDivElement, { value: string }>((props, ref) => null);
            ,
        },
        .{
            .path = "fixture.tsx",
            .source =
            \\import React from "react";
            \\const Component = React.forwardRef<HTMLDivElement, { value: string }>((props, ref) => <div ref={ref}>{props.value}</div>);
            ,
        },
    };

    for (fixtures) |fixture| {
        var result = try lint.lintSource(std.testing.allocator, fixture.source, fixture.path, ruleOptions());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, "parse"));
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.react_no_forward_ref = true;
    return options;
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return diagnostic;
    }
    return null;
}
