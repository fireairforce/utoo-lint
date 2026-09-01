const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const jest_fn_call = @import("jest_fn_call.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "jest/no-identical-title";

const test_message = "Test title is used multiple times in the same describe block";
const describe_message = "Describe block title is used multiple times in the same describe block";

const TitleSet = std.StringHashMapUnmanaged(void);

const DescribeContext = struct {
    describe_titles: TitleSet = .empty,
    test_titles: TitleSet = .empty,

    fn deinit(self: *DescribeContext, allocator: Allocator) void {
        self.describe_titles.deinit(allocator);
        self.test_titles.deinit(allocator);
    }
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    global_aliases: core.JestGlobalAliases,
) Allocator.Error!void {
    var resolver = try jest_fn_call.Resolver.init(allocator, tree, symbol_table, global_aliases);
    defer resolver.deinit();

    var contexts: std.ArrayList(DescribeContext) = .empty;
    defer {
        for (contexts.items) |*context| context.deinit(allocator);
        contexts.deinit(allocator);
    }
    try contexts.append(allocator, .{});

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .resolver = &resolver,
        .contexts = &contexts,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    resolver: *const jest_fn_call.Resolver,
    contexts: *std.ArrayList(DescribeContext),

    pub fn enter_call_expression(
        self: *Visitor,
        call_expression: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const call = self.resolver.parseCall(call_expression, index, ctx.path.parent()) orelse return .proceed;
        const kind = call.function.kind();
        if (kind == .expect) return .proceed;
        const parent_context_index = self.contexts.items.len - 1;

        if (kind == .describe) try self.contexts.append(self.allocator, .{});
        if (call.memberNamed("each") != null) return .proceed;

        const arguments = ctx.tree.extra(call_expression.arguments);
        if (arguments.len == 0) return .proceed;
        const title = staticTitle(ctx.tree, arguments[0]) orelse return .proceed;

        const parent_context = &self.contexts.items[parent_context_index];
        const titles = if (kind == .describe) &parent_context.describe_titles else &parent_context.test_titles;
        const entry = try titles.getOrPut(self.allocator, title);
        if (!entry.found_existing) return .proceed;

        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            if (kind == .describe) describe_message else test_message,
            ctx.tree.span(arguments[0]),
        );
        return .proceed;
    }

    pub fn exit_call_expression(
        self: *Visitor,
        call_expression: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        const call = self.resolver.parseCall(call_expression, index, ctx.path.parent()) orelse return;
        if (call.function.kind() != .describe) return;
        if (self.contexts.pop()) |context_value| {
            var context = context_value;
            context.deinit(self.allocator);
        }
    }
};

fn staticTitle(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateTitle(tree, literal),
        else => null,
    };
}

fn templateTitle(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len != 1) return null;
    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}
