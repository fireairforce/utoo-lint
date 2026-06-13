const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const react_prop_types = @import("react_prop_types.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-unused-prop-types";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    var state = try react_prop_types.collect(allocator, tree);
    defer state.deinit(allocator);

    for (state.components.items) |component| {
        if (!component.detected) continue;
        try reportUnusedProps(allocator, diagnostics, tree, component, component.declared_props.items, "");
    }
}

fn reportUnusedProps(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    component: react_prop_types.ComponentInfo,
    props: []const react_prop_types.DeclaredProp,
    prefix: []const u8,
) Allocator.Error!void {
    for (props) |prop| {
        const full_name = if (prefix.len == 0)
            try allocator.dupe(u8, prop.name)
        else
            try std.fmt.allocPrint(allocator, "{s}.{s}", .{ prefix, prop.name });
        defer allocator.free(full_name);

        if (prop.kind == .shape or prop.kind == .exact) {
            continue;
        }

        if (!componentUsesProp(component, prop.name) and !componentUsesProp(component, full_name)) {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .@"error",
                id,
                tree.span(prop.node),
                "'{s}' PropType is defined but prop is never used",
                .{full_name},
            );
        }

        try reportUnusedProps(allocator, diagnostics, tree, component, prop.children.items, full_name);
    }
}

fn componentUsesProp(component: react_prop_types.ComponentInfo, name: []const u8) bool {
    for (component.used_props.items) |used| {
        if (std.mem.eql(u8, used.name, name)) return true;
    }
    return false;
}
