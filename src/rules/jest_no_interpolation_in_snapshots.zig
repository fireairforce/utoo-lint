const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const jest_fn_call = @import("jest_fn_call.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "jest/no-interpolation-in-snapshots";

const message = "Do not use string interpolation inside of snapshots";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    global_aliases: core.JestGlobalAliases,
) Allocator.Error!void {
    var resolver = try jest_fn_call.Resolver.init(allocator, tree, symbol_table, global_aliases);
    defer resolver.deinit();

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .resolver = &resolver,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    resolver: *const jest_fn_call.Resolver,

    pub fn enter_call_expression(
        self: *Visitor,
        call_expression: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const call = self.resolver.parseCall(call_expression, index, ctx.path.parent()) orelse return .proceed;
        if (call.function.kind() != .expect) return .proceed;

        const matcher = call.lastMember() orelse return .proceed;
        if (!isInlineSnapshotMatcher(matcher.name)) return .proceed;

        for (ctx.tree.extra(call_expression.arguments)) |argument| {
            const template = switch (ctx.tree.data(argument)) {
                .template_literal => |value| value,
                else => continue,
            };
            if (template.expressions.len == 0) continue;
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                message,
                ctx.tree.span(argument),
            );
        }
        return .proceed;
    }
};

fn isInlineSnapshotMatcher(name: []const u8) bool {
    return std.mem.eql(u8, name, "toMatchInlineSnapshot") or
        std.mem.eql(u8, name, "toThrowErrorMatchingInlineSnapshot");
}
