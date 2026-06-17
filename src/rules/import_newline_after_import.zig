const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "import/newline-after-import";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
    count: usize,
    exact_count: bool,
) Allocator.Error!void {
    const body = tree.extra(program.body);
    for (body, 0..) |statement_index, i| {
        if (tree.data(statement_index) != .import_declaration) continue;
        if (i + 1 >= body.len) continue;

        const next_index = body[i + 1];
        if (tree.data(next_index) == .import_declaration) continue;

        const import_end = offsetToLine(tree.source, tree.span(statement_index).end);
        const next_start = offsetToLine(tree.source, tree.span(next_index).start);
        const blank_lines = if (next_start > import_end) next_start - import_end - 1 else 0;
        if (exact_count) {
            if (blank_lines == count) continue;
        } else if (blank_lines >= count) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(statement_index),
            "Expected {d} empty line{s} after import statement not followed by another import.",
            .{ count, if (count == 1) "" else "s" },
        );
    }
}

fn offsetToLine(source: []const u8, offset: u32) usize {
    const end = @min(@as(usize, @intCast(offset)), source.len);
    var line: usize = 1;
    var index: usize = 0;
    while (index < end) : (index += 1) {
        if (source[index] == '\n') line += 1;
    }
    return line;
}
