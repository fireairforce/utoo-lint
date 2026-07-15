const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "one-var";

pub const Options = struct {
    check_var: bool = true,
    check_let: bool = true,
    check_const: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, declaration, index, ctx, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (!shouldCheckKind(declaration.kind, options)) return;
    if (declaration.declarators.len < 2) return;
    if (isForStatementInit(tree, index, ctx)) return;

    var fixes: std.ArrayList(core.Fix) = .empty;
    defer fixes.deinit(allocator);
    var replacements: std.ArrayList([]u8) = .empty;
    defer {
        for (replacements.items) |replacement| allocator.free(replacement);
        replacements.deinit(allocator);
    }

    if (isStatementListContext(tree, ctx) and try buildSplitFixes(allocator, &fixes, &replacements, tree, declaration, ctx)) {
        try core.addDiagnosticWithFixes(
            allocator,
            diagnostics,
            .warning,
            id,
            "Split variable declarations into multiple statements.",
            tree.span(index),
            fixes.items,
        );
        return;
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Split variable declarations into multiple statements.",
        tree.span(index),
    );
}

fn buildSplitFixes(
    allocator: Allocator,
    fixes: *std.ArrayList(core.Fix),
    replacements: *std.ArrayList([]u8),
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!bool {
    const declarators = tree.extra(declaration.declarators);
    const exported = isExportedDeclaration(tree, ctx);
    for (declarators[0 .. declarators.len - 1], declarators[1..]) |current, next| {
        const current_span = tree.span(current);
        const next_span = tree.span(next);
        const comma = findSeparatorComma(tree.source, current_span.end, next_span.start) orelse return false;
        const tail = tree.source[comma + 1 .. next_span.start];
        const preserve_tail = hasComment(tail) or containsLineTerminator(tail);
        const replacement = if (preserve_tail)
            try std.fmt.allocPrint(allocator, ";{s}{s}{s}{s} ", .{
                tail,
                if (exported) "export " else "",
                if (declaration.declare) "declare " else "",
                declaration.kind.toString(),
            })
        else
            try std.fmt.allocPrint(allocator, "; {s}{s}{s} ", .{
                if (exported) "export " else "",
                if (declaration.declare) "declare " else "",
                declaration.kind.toString(),
            });
        replacements.append(allocator, replacement) catch |err| {
            allocator.free(replacement);
            return err;
        };

        try fixes.append(allocator, .{
            .span = .{ .start = comma, .end = next_span.start },
            .replacement = replacement,
        });
    }
    return fixes.items.len == declarators.len - 1;
}

fn isExportedDeclaration(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.ancestor(1) orelse return false;
    return tree.data(parent) == .export_named_declaration;
}

fn findSeparatorComma(source: []const u8, start: u32, end: u32) ?u32 {
    var index: usize = @intCast(start);
    const limit: usize = @intCast(end);

    while (index < limit) {
        if (source[index] == ',') return @intCast(index);
        if (source[index] == '/' and index + 1 < limit) {
            if (source[index + 1] == '/') {
                index += 2;
                while (index < limit and source[index] != '\n' and source[index] != '\r') index += 1;
                continue;
            }
            if (source[index + 1] == '*') {
                index += 2;
                while (index + 1 < limit and !(source[index] == '*' and source[index + 1] == '/')) index += 1;
                if (index + 1 >= limit) return null;
                index += 2;
                continue;
            }
        }
        if (!std.ascii.isWhitespace(source[index])) return null;
        index += 1;
    }
    return null;
}

fn hasComment(source: []const u8) bool {
    return std.mem.indexOf(u8, source, "//") != null or std.mem.indexOf(u8, source, "/*") != null;
}

fn containsLineTerminator(source: []const u8) bool {
    for (source) |char| {
        if (char == '\n' or char == '\r') return true;
    }
    return false;
}

fn isStatementListContext(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var parent = ctx.path.ancestor(1) orelse return false;
    if (tree.data(parent) == .export_named_declaration) {
        parent = ctx.path.ancestor(2) orelse return false;
    }

    return switch (tree.data(parent)) {
        .program,
        .function_body,
        .block_statement,
        .static_block,
        .switch_case,
        .ts_module_block,
        => true,
        else => false,
    };
}

fn shouldCheckKind(kind: ast.VariableKind, options: Options) bool {
    return switch (kind) {
        .@"var" => options.check_var,
        .let => options.check_let,
        .@"const" => options.check_const,
        .using, .await_using => true,
    };
}

fn isForStatementInit(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    const parent_index = ctx.path.ancestor(1) orelse return false;
    return switch (tree.data(parent_index)) {
        .for_statement => |statement| statement.init == index,
        else => false,
    };
}
