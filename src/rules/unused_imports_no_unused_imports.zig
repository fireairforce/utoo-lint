const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;
const SymbolId = traverser.semantic.SymbolId;
const DeclSymbolMap = std.AutoHashMap(ast.NodeIndex, SymbolId);

pub const id = "unused-imports/no-unused-imports";

const BindingKind = enum {
    default,
    named,
    namespace,
};

const Binding = struct {
    specifier: ast.NodeIndex,
    local: ast.NodeIndex,
    kind: BindingKind,
    used: bool,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var decl_symbols = DeclSymbolMap.init(allocator);
    defer decl_symbols.deinit();

    var symbols = symbol_table.iterSymbols();
    while (symbols.next()) |entry| {
        if (!entry.symbol.flags.import and !entry.symbol.flags.type_import) continue;
        for (symbol_table.symbolDecls(entry.id)) |decl| {
            try decl_symbols.put(decl, entry.id);
        }
    }

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .decl_symbols = &decl_symbols,
        .symbol_table = symbol_table,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    decl_symbols: *const DeclSymbolMap,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_import_declaration(
        self: *Visitor,
        declaration: ast.ImportDeclaration,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const specifiers = ctx.tree.extra(declaration.specifiers);
        if (specifiers.len == 0) return .proceed;

        var bindings: std.ArrayList(Binding) = .empty;
        defer bindings.deinit(self.allocator);

        for (specifiers) |specifier| {
            const binding = bindingForSpecifier(ctx.tree, specifier) orelse continue;
            const symbol_id = self.decl_symbols.get(binding.local) orelse continue;
            try bindings.append(self.allocator, .{
                .specifier = specifier,
                .local = binding.local,
                .kind = binding.kind,
                .used = self.symbol_table.isReferenced(symbol_id),
            });
        }

        var unused_count: usize = 0;
        for (bindings.items) |binding| {
            if (!binding.used) unused_count += 1;
        }
        if (unused_count == 0) return .proceed;

        var fixes: std.ArrayList(core.Fix) = .empty;
        defer fixes.deinit(self.allocator);
        var replacements: std.ArrayList([]u8) = .empty;
        defer {
            for (replacements.items) |replacement| self.allocator.free(replacement);
            replacements.deinit(self.allocator);
        }

        const can_fix = try buildFixes(
            self.allocator,
            &fixes,
            &replacements,
            ctx.tree,
            declaration,
            index,
            bindings.items,
            unused_count,
        );

        var emitted_fix = false;
        for (bindings.items) |binding| {
            if (binding.used) continue;
            const name = bindingName(ctx.tree, binding.local);
            const message = try std.fmt.allocPrint(self.allocator, "'{s}' is defined but never used.", .{name});
            defer self.allocator.free(message);

            if (can_fix and !emitted_fix) {
                try core.addDiagnosticWithFixes(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    message,
                    ctx.tree.span(binding.local),
                    fixes.items,
                );
                emitted_fix = true;
            } else {
                try core.addDiagnostic(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    message,
                    ctx.tree.span(binding.local),
                );
            }
        }

        return .proceed;
    }
};

const SpecifierBinding = struct {
    local: ast.NodeIndex,
    kind: BindingKind,
};

fn bindingForSpecifier(tree: *const ast.Tree, index: ast.NodeIndex) ?SpecifierBinding {
    return switch (tree.data(index)) {
        .import_default_specifier => |specifier| .{ .local = specifier.local, .kind = .default },
        .import_specifier => |specifier| .{ .local = specifier.local, .kind = .named },
        .import_namespace_specifier => |specifier| .{ .local = specifier.local, .kind = .namespace },
        else => null,
    };
}

fn bindingName(tree: *const ast.Tree, index: ast.NodeIndex) []const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => "import",
    };
}

fn buildFixes(
    allocator: Allocator,
    fixes: *std.ArrayList(core.Fix),
    replacements: *std.ArrayList([]u8),
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    declaration_index: ast.NodeIndex,
    bindings: []const Binding,
    unused_count: usize,
) Allocator.Error!bool {
    if (unused_count == bindings.len) {
        const declaration_span = tree.span(declaration_index);
        const replacement = try commentsOnlyReplacement(allocator, tree, declaration_span);
        errdefer allocator.free(replacement);
        try replacements.append(allocator, replacement);
        try fixes.append(allocator, .{
            .span = declarationRemovalSpan(tree.source, declaration_span),
            .replacement = replacement,
        });
        return true;
    }

    for (bindings) |binding| {
        if (!binding.used) {
            try fixes.append(allocator, .{ .span = bindingRemovalSpan(tree, binding.specifier), .replacement = "" });
        }
    }

    var default_index: ?usize = null;
    var namespace_index: ?usize = null;
    var named_start: ?usize = null;
    var named_end: usize = 0;
    for (bindings, 0..) |binding, binding_index| {
        switch (binding.kind) {
            .default => default_index = binding_index,
            .namespace => namespace_index = binding_index,
            .named => {
                if (named_start == null) named_start = binding_index;
                named_end = binding_index + 1;
            },
        }
    }

    if (namespace_index) |ns_index| {
        if (default_index) |def_index| {
            if (bindings[def_index].used != bindings[ns_index].used) {
                const comma = findByteOutsideComments(
                    tree,
                    tree.span(bindings[def_index].specifier).end,
                    tree.span(bindings[ns_index].specifier).start,
                    ',',
                ) orelse return false;
                try appendRemoval(allocator, fixes, comma);
            }
        }
        return finishPartialFixes(allocator, fixes, tree, bindings);
    }

    const first_named = named_start orelse return finishPartialFixes(allocator, fixes, tree, bindings);
    const named = bindings[first_named..named_end];
    var used_named_count: usize = 0;
    for (named) |binding| {
        if (binding.used) used_named_count += 1;
    }

    const first_named_span = tree.span(named[0].specifier);
    const last_named_span = tree.span(named[named.len - 1].specifier);
    const left_search_start = if (default_index) |def_index|
        tree.span(bindings[def_index].specifier).end
    else
        tree.span(declaration_index).start;
    const left_brace = findByteOutsideComments(tree, left_search_start, first_named_span.start, '{') orelse return false;
    const right_brace = findLastByteOutsideComments(tree, last_named_span.end, tree.span(declaration.source).start, '}') orelse return false;

    if (used_named_count == 0) {
        const def_index = default_index orelse return false;
        if (!bindings[def_index].used) return false;

        const separator = findByteOutsideComments(
            tree,
            tree.span(bindings[def_index].specifier).end,
            left_brace,
            ',',
        ) orelse return false;
        try appendRemoval(allocator, fixes, separator);
        try appendRemoval(allocator, fixes, left_brace);
        try appendByteRemovalsOutsideComments(allocator, fixes, tree, left_brace + 1, right_brace, ',');
        try appendRemoval(allocator, fixes, right_brace);
        return finishPartialFixes(allocator, fixes, tree, bindings);
    }

    if (default_index) |def_index| {
        if (!bindings[def_index].used) {
            const separator = findByteOutsideComments(
                tree,
                tree.span(bindings[def_index].specifier).end,
                left_brace,
                ',',
            ) orelse return false;
            try appendRemoval(allocator, fixes, separator);
        }
    }

    var seen_used_named: usize = 0;
    for (named[0 .. named.len - 1], 0..) |binding, named_index| {
        if (binding.used) seen_used_named += 1;
        const next = named[named_index + 1];
        const comma = findByteOutsideComments(
            tree,
            tree.span(binding.specifier).end,
            tree.span(next.specifier).start,
            ',',
        ) orelse return false;
        const keep_comma = binding.used and seen_used_named < used_named_count;
        if (!keep_comma) try appendRemoval(allocator, fixes, comma);
    }

    return finishPartialFixes(allocator, fixes, tree, bindings);
}

fn finishPartialFixes(
    allocator: Allocator,
    fixes: *std.ArrayList(core.Fix),
    tree: *const ast.Tree,
    bindings: []const Binding,
) Allocator.Error!bool {
    try collapseEmptySpecifierLines(allocator, fixes, tree, bindings);
    return true;
}

fn collapseEmptySpecifierLines(
    allocator: Allocator,
    fixes: *std.ArrayList(core.Fix),
    tree: *const ast.Tree,
    bindings: []const Binding,
) Allocator.Error!void {
    for (bindings) |binding| {
        if (binding.used) continue;

        const specifier_span = tree.span(binding.specifier);
        const line_start = lineStart(tree.source, specifier_span.start);
        const line_end = lineEnd(tree.source, specifier_span.end);
        if (!lineIsWhitespaceAfterFixes(tree.source, line_start, line_end, fixes.items)) continue;

        var fix_index = fixes.items.len;
        while (fix_index > 0) {
            fix_index -= 1;
            const fix = fixes.items[fix_index];
            if (fix.span.start >= line_start and fix.span.end <= line_end) {
                _ = fixes.orderedRemove(fix_index);
            }
        }
        try fixes.append(allocator, .{
            .span = .{ .start = line_start, .end = line_end },
            .replacement = "",
        });
    }
}

fn lineIsWhitespaceAfterFixes(source: []const u8, start: u32, end: u32, fixes: []const core.Fix) bool {
    var position = start;
    while (position < end) : (position += 1) {
        if (source[position] == '\n' or source[position] == '\r') continue;
        if (positionDeleted(position, fixes)) continue;
        if (!std.ascii.isWhitespace(source[position])) return false;
    }
    return true;
}

fn positionDeleted(position: u32, fixes: []const core.Fix) bool {
    for (fixes) |fix| {
        if (fix.replacement.len == 0 and position >= fix.span.start and position < fix.span.end) return true;
    }
    return false;
}

fn lineStart(source: []const u8, offset: u32) u32 {
    var position = offset;
    while (position > 0 and source[position - 1] != '\n') position -= 1;
    return position;
}

fn lineEnd(source: []const u8, offset: u32) u32 {
    var position = offset;
    while (position < source.len and source[position] != '\n') position += 1;
    if (position < source.len) position += 1;
    return position;
}

fn commentsOnlyReplacement(allocator: Allocator, tree: *const ast.Tree, span: ast.Span) Allocator.Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    var cursor = span.start;
    for (tree.comments) |comment| {
        if (comment.span.start < span.start or comment.span.end > span.end) continue;
        try appendLineBreaks(allocator, &output, tree.source[cursor..comment.span.start]);
        try output.appendSlice(allocator, tree.source[comment.span.start..comment.span.end]);
        cursor = comment.span.end;
    }
    try appendLineBreaks(allocator, &output, tree.source[cursor..span.end]);
    return output.toOwnedSlice(allocator);
}

fn appendLineBreaks(allocator: Allocator, output: *std.ArrayList(u8), source: []const u8) Allocator.Error!void {
    for (source) |byte| {
        if (byte == '\r' or byte == '\n') try output.append(allocator, byte);
    }
}

fn declarationRemovalSpan(source: []const u8, declaration_span: ast.Span) ast.Span {
    var start = declaration_span.start;
    const start_of_line = lineStart(source, start);
    while (start > start_of_line and isHorizontalWhitespace(source[start - 1])) start -= 1;

    var end = declaration_span.end;
    while (end < source.len and isHorizontalWhitespace(source[end])) end += 1;
    return .{ .start = start, .end = end };
}

fn bindingRemovalSpan(tree: *const ast.Tree, specifier: ast.NodeIndex) ast.Span {
    var span = tree.span(specifier);
    const start_of_line = lineStart(tree.source, span.start);
    while (span.start > start_of_line and isHorizontalWhitespace(tree.source[span.start - 1])) span.start -= 1;
    return span;
}

fn isHorizontalWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t';
}

fn appendRemoval(allocator: Allocator, fixes: *std.ArrayList(core.Fix), position: u32) Allocator.Error!void {
    try fixes.append(allocator, .{
        .span = .{ .start = position, .end = position + 1 },
        .replacement = "",
    });
}

fn appendByteRemovalsOutsideComments(
    allocator: Allocator,
    fixes: *std.ArrayList(core.Fix),
    tree: *const ast.Tree,
    start: u32,
    end: u32,
    needle: u8,
) Allocator.Error!void {
    var position = start;
    while (position < end) : (position += 1) {
        if (tree.source[position] == needle and !insideComment(tree, position)) {
            try appendRemoval(allocator, fixes, position);
        }
    }
}

fn findByteOutsideComments(tree: *const ast.Tree, start: u32, end: u32, needle: u8) ?u32 {
    var position = start;
    while (position < end) : (position += 1) {
        if (tree.source[position] == needle and !insideComment(tree, position)) return position;
    }
    return null;
}

fn findLastByteOutsideComments(tree: *const ast.Tree, start: u32, end: u32, needle: u8) ?u32 {
    var position = end;
    while (position > start) {
        position -= 1;
        if (tree.source[position] == needle and !insideComment(tree, position)) return position;
    }
    return null;
}

fn insideComment(tree: *const ast.Tree, position: u32) bool {
    for (tree.comments) |comment| {
        if (position < comment.span.start) return false;
        if (position < comment.span.end) return true;
    }
    return false;
}
