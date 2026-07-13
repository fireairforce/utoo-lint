const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const no_new_object = @import("no_new_object.zig");
const no_object_constructor = @import("no_object_constructor.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    check_no_new_object: bool,
    check_no_object_constructor: bool,
) Allocator.Error!void {
    if (!check_no_new_object and !check_no_object_constructor) return;

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .check_no_new_object = check_no_new_object,
        .check_no_object_constructor = check_no_object_constructor,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    check_no_new_object: bool,
    check_no_object_constructor: bool,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.check_no_object_constructor and
            call.arguments.len == 0 and
            isGlobalObjectReference(ctx.tree, self.symbol_table, call.callee))
        {
            try self.reportNoObjectConstructor(ctx.tree, index);
        }

        return .proceed;
    }

    pub fn enter_new_expression(
        self: *Visitor,
        expression: ast.NewExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const is_global_object = isGlobalObjectReference(ctx.tree, self.symbol_table, expression.callee);

        if (self.check_no_new_object and is_global_object) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                no_new_object.id,
                "Do not use Object as a constructor.",
                ctx.tree.span(index),
            );
        }

        if (self.check_no_object_constructor and expression.arguments.len == 0 and is_global_object) {
            try self.reportNoObjectConstructor(ctx.tree, index);
        }

        return .proceed;
    }

    fn reportNoObjectConstructor(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            no_object_constructor.id,
            "Do not use the Object constructor.",
            tree.span(index),
        );
    }
};

fn isGlobalObjectReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    const name = identifierReferenceName(tree, unwrapped) orelse return false;

    return std.mem.eql(u8, name, "Object") and isUnresolvedReference(symbol_table, unwrapped);
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

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isUnresolvedReference(
    symbol_table: traverser.semantic.SymbolTable,
    node: ast.NodeIndex,
) bool {
    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        if (entry.reference.node == node) {
            return symbol_table.referenceSymbol(entry.id) == .none;
        }
    }

    return false;
}
