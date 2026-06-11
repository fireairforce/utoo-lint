const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-empty-character-class";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.RegExpLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasEmptyCharacterClass(tree.string(literal.pattern))) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Empty character classes are not allowed.",
        tree.span(index),
    );
}

fn hasEmptyCharacterClass(pattern: []const u8) bool {
    var escaped = false;
    var index: usize = 0;

    while (index < pattern.len) : (index += 1) {
        const char = pattern[index];
        if (escaped) {
            escaped = false;
            continue;
        }

        if (char == '\\') {
            escaped = true;
            continue;
        }

        if (char == '[' and index + 1 < pattern.len and pattern[index + 1] == ']') {
            return true;
        }
    }

    return false;
}
