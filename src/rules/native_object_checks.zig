const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const no_new_native_nonconstructor = @import("no_new_native_nonconstructor.zig");
const no_obj_calls = @import("no_obj_calls.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    check_no_new_native_nonconstructor: bool,
    check_no_obj_calls: bool,
) Allocator.Error!void {
    if (!check_no_new_native_nonconstructor and !check_no_obj_calls) return;

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .check_no_new_native_nonconstructor = check_no_new_native_nonconstructor,
        .check_no_obj_calls = check_no_obj_calls,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    check_no_new_native_nonconstructor: bool,
    check_no_obj_calls: bool,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.check_no_obj_calls) {
            if (globalObjectName(ctx.tree, self.symbol_table, call.callee)) |name| {
                try self.reportNoObjCalls(ctx.tree, index, name);
            }
        }

        return .proceed;
    }

    pub fn enter_new_expression(
        self: *Visitor,
        expression: ast.NewExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const callee = unwrapTransparent(ctx.tree, expression.callee);
        const name = identifierReferenceName(ctx.tree, callee) orelse return .proceed;

        if (self.check_no_new_native_nonconstructor and isNativeNonconstructorName(name)) {
            if (isUnresolvedReference(self.symbol_table, callee)) {
                try core.addDiagnosticFmt(
                    self.allocator,
                    self.diagnostics,
                    .@"error",
                    no_new_native_nonconstructor.id,
                    ctx.tree.span(index),
                    "`{s}` cannot be called as a constructor.",
                    .{name},
                );
            }
        }

        if (self.check_no_obj_calls and isForbiddenObject(name)) {
            if (isUnresolvedReference(self.symbol_table, callee)) {
                try self.reportNoObjCalls(ctx.tree, index, name);
            }
        }

        return .proceed;
    }

    fn reportNoObjCalls(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) Allocator.Error!void {
        try core.addDiagnosticFmt(
            self.allocator,
            self.diagnostics,
            .warning,
            no_obj_calls.id,
            tree.span(index),
            "'{s}' is not a function.",
            .{name},
        );
    }
};

fn globalObjectName(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    callee: ast.NodeIndex,
) ?[]const u8 {
    const unwrapped = unwrapTransparent(tree, callee);
    const name = identifierReferenceName(tree, unwrapped) orelse return null;
    if (!isForbiddenObject(name)) return null;
    if (!isUnresolvedReference(symbol_table, unwrapped)) return null;
    return name;
}

fn isNativeNonconstructorName(name: []const u8) bool {
    return std.mem.eql(u8, name, "Symbol") or
        std.mem.eql(u8, name, "BigInt");
}

fn isForbiddenObject(name: []const u8) bool {
    return std.mem.eql(u8, name, "Math") or
        std.mem.eql(u8, name, "JSON") or
        std.mem.eql(u8, name, "Reflect") or
        std.mem.eql(u8, name, "Atomics") or
        std.mem.eql(u8, name, "Intl");
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
