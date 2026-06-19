const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "sort-vars";

pub const Options = struct {
    ignore_case: bool = false,
};

pub fn checkVariableDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    options: Options,
) Allocator.Error!void {
    var previous_name: ?[]const u8 = null;

    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |declarator| declarator,
            else => continue,
        };
        const name = bindingIdentifierName(tree, declarator.id) orelse continue;

        if (previous_name) |previous| {
            if (compareNames(name, previous, options.ignore_case) < 0) {
                try core.addDiagnostic(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    "Variables within the same declaration block should be sorted alphabetically.",
                    tree.span(declarator.id),
                );
                continue;
            }
        }

        previous_name = name;
    }
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn compareNames(left: []const u8, right: []const u8, ignore_case: bool) i8 {
    const min_len = @min(left.len, right.len);
    for (0..min_len) |index| {
        const left_char = normalizeChar(left[index], ignore_case);
        const right_char = normalizeChar(right[index], ignore_case);
        if (left_char < right_char) return -1;
        if (left_char > right_char) return 1;
    }

    if (left.len < right.len) return -1;
    if (left.len > right.len) return 1;
    return 0;
}

fn normalizeChar(char: u8, ignore_case: bool) u8 {
    return if (ignore_case) std.ascii.toLower(char) else char;
}
