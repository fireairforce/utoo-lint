const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const jest_fn_call = @import("jest_fn_call.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "jest/no-focused-tests";

const message = "Unexpected focused test";
const suggestion_message = "Remove focus from test";

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

        if (call.function.isFocused()) {
            if (call.isAliasedImport()) {
                try core.addDiagnostic(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    message,
                    ctx.tree.span(call.head),
                );
                return .proceed;
            }

            const head_span = ctx.tree.span(call.head);
            try core.addDiagnosticWithSuggestions(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                message,
                head_span,
                &.{.{
                    .message = suggestion_message,
                    .fixes = &.{.{
                        .span = .{ .start = head_span.start, .end = head_span.start + 1 },
                        .replacement = "",
                    }},
                }},
            );
            return .proceed;
        }

        const only = call.memberNamed("only") orelse return .proceed;
        const property_span = ctx.tree.span(only.node);
        if (property_span.start == 0) return .proceed;
        const end = property_span.end + @intFromBool(only.computed);
        if (end > ctx.tree.source.len) return .proceed;

        try core.addDiagnosticWithSuggestions(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            message,
            property_span,
            &.{.{
                .message = suggestion_message,
                .fixes = &.{.{
                    .span = .{ .start = property_span.start - 1, .end = end },
                    .replacement = "",
                }},
            }},
        );
        return .proceed;
    }
};
