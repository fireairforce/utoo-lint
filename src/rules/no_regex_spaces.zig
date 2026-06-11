const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-regex-spaces";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.RegExpLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasConsecutiveSpaces(tree.string(literal.pattern))) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Avoid multiple spaces in regular expression literals.",
        tree.span(index),
    );
}

fn hasConsecutiveSpaces(pattern: []const u8) bool {
    var in_class = false;
    var escaped = false;
    var previous_space = false;

    for (pattern) |char| {
        if (escaped) {
            escaped = false;
            previous_space = false;
            continue;
        }

        switch (char) {
            '\\' => {
                escaped = true;
                previous_space = false;
            },
            '[' => {
                in_class = true;
                previous_space = false;
            },
            ']' => {
                in_class = false;
                previous_space = false;
            },
            ' ' => {
                if (!in_class and previous_space) return true;
                previous_space = !in_class;
            },
            else => previous_space = false,
        }
    }

    return false;
}
