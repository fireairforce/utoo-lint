const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-require-imports";

const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, traverser.semantic.SymbolId);

pub const Options = struct {
    allow_as_import: bool = false,
    allow: core.TypescriptEslintNoRequireImportsAllowPatterns = .{},
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    options: Options,
) Allocator.Error!void {
    if (std.mem.indexOf(u8, tree.source, "require") == null) return;

    var reference_lookup = try buildReferenceLookup(allocator, symbol_table);
    defer reference_lookup.deinit();

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .reference_lookup = &reference_lookup,
        .options = options,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    reference_lookup: *const ReferenceLookup,
    options: Options,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.isGlobalRequireReference(ctx.tree, call.callee)) {
            if (callSource(ctx.tree, call)) |source| {
                if (isAllowedSource(source, self.options.allow)) return .proceed;
            }
            try self.addDiagnostic(ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_ts_external_module_reference(
        self: *Visitor,
        reference: ast.TSExternalModuleReference,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (stringLiteralValue(ctx.tree, reference.expression)) |source| {
            if (isAllowedSource(source, self.options.allow)) return .proceed;
        }
        if (self.options.allow_as_import) return .proceed;
        try self.addDiagnostic(ctx.tree, index);
        return .proceed;
    }

    fn isGlobalRequireReference(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) bool {
        const name = identifierReferenceName(tree, index) orelse return false;
        if (!std.mem.eql(u8, name, "require")) return false;

        return (self.reference_lookup.get(index) orelse .none) == .none;
    }

    fn addDiagnostic(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "A `require()` style import is forbidden.",
            tree.span(index),
        );
    }
};

fn buildReferenceLookup(
    allocator: Allocator,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!ReferenceLookup {
    var lookup = ReferenceLookup.init(allocator);
    errdefer lookup.deinit();
    try lookup.ensureTotalCapacity(@intCast(symbol_table.references.len));

    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        try lookup.put(entry.reference.node, symbol_table.referenceSymbol(entry.id));
    }

    return lookup;
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn callSource(tree: *const ast.Tree, call: ast.CallExpression) ?[]const u8 {
    const arguments = tree.extra(call.arguments);
    if (arguments.len != 1) return null;
    return stringLiteralValue(tree, arguments[0]);
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn isAllowedSource(source: []const u8, allow: core.TypescriptEslintNoRequireImportsAllowPatterns) bool {
    for (0..allow.count) |index| {
        if (matchesAllowPattern(allow.at(index), source)) return true;
    }
    return false;
}

fn matchesAllowPattern(pattern: []const u8, source: []const u8) bool {
    if (pattern.len == 0) return false;
    const anchored_start = pattern[0] == '^';
    const anchored_end = hasUnescapedTrailingDollar(pattern);
    const start: usize = if (anchored_start) 1 else 0;
    const end: usize = if (anchored_end) pattern.len - 1 else pattern.len;
    const body = pattern[start..end];

    if (anchored_start) {
        return matchPatternAt(body, 0, source, 0, anchored_end);
    }

    for (0..source.len + 1) |source_index| {
        if (matchPatternAt(body, 0, source, source_index, anchored_end)) return true;
    }
    return false;
}

fn hasUnescapedTrailingDollar(pattern: []const u8) bool {
    if (pattern.len == 0 or pattern[pattern.len - 1] != '$') return false;
    var slash_count: usize = 0;
    var index = pattern.len - 1;
    while (index > 0) {
        index -= 1;
        if (pattern[index] != '\\') break;
        slash_count += 1;
    }
    return slash_count % 2 == 0;
}

fn matchPatternAt(pattern: []const u8, pattern_index: usize, source: []const u8, source_index: usize, anchored_end: bool) bool {
    if (pattern_index >= pattern.len) return !anchored_end or source_index == source.len;

    const token = readPatternToken(pattern, pattern_index);
    const next_index = token.next_index;
    if (next_index < pattern.len and pattern[next_index] == '*') {
        var end_index = source_index;
        while (end_index < source.len and token.matches(source[end_index])) {
            end_index += 1;
        }
        while (true) {
            if (matchPatternAt(pattern, next_index + 1, source, end_index, anchored_end)) return true;
            if (end_index == source_index) break;
            end_index -= 1;
        }
        return false;
    }

    if (source_index >= source.len or !token.matches(source[source_index])) return false;
    return matchPatternAt(pattern, next_index, source, source_index + 1, anchored_end);
}

const PatternToken = struct {
    kind: enum { any, literal },
    literal: u8 = 0,
    next_index: usize,

    fn matches(self: PatternToken, value: u8) bool {
        return switch (self.kind) {
            .any => true,
            .literal => self.literal == value,
        };
    }
};

fn readPatternToken(pattern: []const u8, index: usize) PatternToken {
    if (pattern[index] == '\\' and index + 1 < pattern.len) {
        return .{
            .kind = .literal,
            .literal = pattern[index + 1],
            .next_index = index + 2,
        };
    }
    if (pattern[index] == '.') {
        return .{
            .kind = .any,
            .next_index = index + 1,
        };
    }
    return .{
        .kind = .literal,
        .literal = pattern[index],
        .next_index = index + 1,
    };
}
