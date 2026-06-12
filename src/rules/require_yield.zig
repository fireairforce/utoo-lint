const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "require-yield";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!function.generator or function.body == .null) return;
    if (containsYield(tree, function.body)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "This generator function does not have 'yield'.",
        tree.span(index),
    );
}

fn containsYield(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .yield_expression => true,
        .function,
        .arrow_function_expression,
        => false,
        inline else => |node| nodeContainsYield(tree, node),
    };
}

fn nodeContainsYield(tree: *const ast.Tree, node: anytype) bool {
    const T = @TypeOf(node);
    if (@typeInfo(T) != .@"struct") return false;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (field.type == ast.NodeIndex) {
            if (containsYield(tree, @field(node, field.name))) return true;
        } else if (field.type == ast.IndexRange) {
            for (tree.extra(@field(node, field.name))) |child| {
                if (containsYield(tree, child)) return true;
            }
        }
    }

    return false;
}
