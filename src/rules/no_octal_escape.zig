const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-octal-escape";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasOctalEscape(tree, index)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Octal escape sequences should not be used.",
        tree.span(index),
    );
}

fn hasOctalEscape(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start >= end or end > tree.source.len) return false;

    const source = tree.source[start..end];
    var offset: usize = 0;
    while (offset < source.len) {
        if (source[offset] != '\\' or offset + 1 >= source.len) {
            offset += 1;
            continue;
        }

        const escaped = source[offset + 1];
        if (isOctalDigit(escaped) and (escaped != '0' or isNextOctalDigit(source, offset + 2))) {
            return true;
        }

        offset += 2;
    }

    return false;
}

fn isNextOctalDigit(source: []const u8, offset: usize) bool {
    return offset < source.len and isOctalDigit(source[offset]);
}

fn isOctalDigit(byte: u8) bool {
    return byte >= '0' and byte <= '7';
}
