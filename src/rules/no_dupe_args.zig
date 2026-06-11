const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-dupe-args";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
) Allocator.Error!void {
    if (function.params == .null) return;

    const params = switch (tree.data(function.params)) {
        .formal_parameters => |params| params,
        else => return,
    };

    var seen: std.StringHashMapUnmanaged(void) = .empty;
    defer seen.deinit(allocator);

    for (tree.extra(params.items)) |param_index| {
        const parameter = switch (tree.data(param_index)) {
            .formal_parameter => |parameter| parameter,
            else => continue,
        };

        const name = parameterName(tree, parameter.pattern) orelse continue;
        const result = try seen.getOrPut(allocator, name);
        if (result.found_existing) {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                tree.span(parameter.pattern),
                "Duplicate parameter '{s}'.",
                .{name},
            );
        }
    }
}

fn parameterName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        .assignment_pattern => |pattern| parameterName(tree, pattern.left),
        else => null,
    };
}
