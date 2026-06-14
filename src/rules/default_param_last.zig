const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "default-param-last";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params_index: ast.NodeIndex,
) Allocator.Error!void {
    const params = formalParameters(tree, params_index) orelse return;
    var required_after = false;

    const items = tree.extra(params.items);
    var index = items.len;
    while (index > 0) {
        index -= 1;

        const parameter = parameterPattern(tree, items[index]) orelse continue;
        if (isDefaultParameter(tree, parameter)) {
            if (required_after) {
                try core.addDiagnostic(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    "Default parameters should be last.",
                    tree.span(parameter),
                );
            }
            continue;
        }

        if (isRequiredParameter(tree, parameter)) {
            required_after = true;
        }
    }
}

fn formalParameters(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.FormalParameters {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .formal_parameters => |params| params,
        else => null,
    };
}

fn parameterPattern(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .formal_parameter => |parameter| parameter.pattern,
        .ts_parameter_property => |property| property.parameter,
        else => null,
    };
}

fn isDefaultParameter(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .assignment_pattern => true,
        else => false,
    };
}

fn isRequiredParameter(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .assignment_pattern, .ts_this_parameter => false,
        .binding_identifier => |identifier| !identifier.optional,
        .array_pattern => |pattern| !pattern.optional,
        .object_pattern => |pattern| !pattern.optional,
        else => true,
    };
}
