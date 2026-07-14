const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-undef-init";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_variable_declaration(
        self: *Visitor,
        declaration: ast.VariableDeclaration,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try check(self.allocator, self.diagnostics, ctx.tree, declaration, self.symbol_table);
        return .proceed;
    }
};

fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    if (declaration.kind == .@"const") return;

    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |declarator| declarator,
            else => continue,
        };

        const reference = undefinedReference(tree, declarator.init) orelse continue;
        const reference_id = symbol_table.model.referenceOf(reference) orelse continue;
        if (symbol_table.referenceSymbol(reference_id) != .none) continue;

        const diagnostic_span = tree.span(declarator.init);
        const binding_span = tree.span(declarator.id);
        if (declaration.kind == .let and
            isBindingIdentifier(tree, declarator.id) and
            !hasCommentBetween(tree, binding_span.end, diagnostic_span.end))
        {
            try core.addDiagnosticWithFix(
                allocator,
                diagnostics,
                .warning,
                id,
                "Do not initialize variables to undefined.",
                diagnostic_span,
                .{
                    .span = .{
                        .start = binding_span.end,
                        .end = diagnostic_span.end,
                    },
                    .replacement = "",
                },
            );
        } else {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "Do not initialize variables to undefined.",
                diagnostic_span,
            );
        }
    }
}

fn isBindingIdentifier(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .binding_identifier => true,
        else => false,
    };
}

fn hasCommentBetween(tree: *const ast.Tree, start: u32, end: u32) bool {
    for (tree.comments) |comment| {
        if (comment.span.start < end and comment.span.end > start) return true;
    }
    return false;
}

fn undefinedReference(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    if (index == .null) return null;

    const unwrapped = unwrapTransparent(tree, index);
    return switch (tree.data(unwrapped)) {
        .identifier_reference => |identifier| if (std.mem.eql(u8, tree.string(identifier.name), "undefined")) unwrapped else null,
        else => null,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;

    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }

    return current;
}
