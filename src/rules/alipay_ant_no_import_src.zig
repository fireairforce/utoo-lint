const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/no-import-src";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
) Allocator.Error!void {
    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        const source = importSource(tree, declaration) orelse continue;
        if (!matchesImportSrcPattern(source)) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(statement_index),
            "Import code from '{s}' may break your App for compatibility issues.",
            .{source},
        );
    }
}

fn importSource(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ?[]const u8 {
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn matchesImportSrcPattern(source: []const u8) bool {
    if (source.len == 0) return false;

    var end = source.len;
    if (source[end - 1] == '/') {
        end -= 1;
        if (end == 0) return false;
    }

    const trimmed = source[0..end];
    var src_segment_index: usize = 0;
    var found_src_segment = false;
    var segment_count: usize = 0;

    var iter = std.mem.splitScalar(u8, trimmed, '/');
    while (iter.next()) |segment| {
        if (segment.len == 0) return false;
        if (!found_src_segment and std.mem.eql(u8, segment, "src")) {
            src_segment_index = segment_count;
            found_src_segment = true;
        }
        segment_count += 1;
    }

    if (!found_src_segment) return false;

    var index: usize = 0;
    iter = std.mem.splitScalar(u8, trimmed, '/');
    while (iter.next()) |segment| : (index += 1) {
        if (index < src_segment_index) {
            if (!isPrefixSegment(segment)) return false;
        } else if (index > src_segment_index) {
            if (!isPathSegment(segment)) return false;
        }
    }

    return true;
}

fn isPrefixSegment(segment: []const u8) bool {
    if (segment.len == 0) return false;

    const start: usize = if (segment[0] == '@') 1 else 0;
    if (start >= segment.len) return false;
    if (!isSegmentFirstChar(segment[start])) return false;

    for (segment[start + 1 ..]) |char| {
        if (!isSegmentRestChar(char)) return false;
    }
    return true;
}

fn isPathSegment(segment: []const u8) bool {
    if (segment.len == 0) return false;
    if (!isSegmentFirstChar(segment[0])) return false;

    for (segment[1..]) |char| {
        if (!isSegmentRestChar(char)) return false;
    }
    return true;
}

fn isSegmentFirstChar(char: u8) bool {
    return std.ascii.isAlphanumeric(char) or char == '-' or char == '*' or char == '~';
}

fn isSegmentRestChar(char: u8) bool {
    return isSegmentFirstChar(char) or char == '.' or char == '_';
}
