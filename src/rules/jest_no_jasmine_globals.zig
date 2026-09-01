const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "jest/no-jasmine-globals";

const illegal_fail = "Illegal usage of `fail`, prefer throwing an error, or the `done.fail` callback";
const illegal_pending = "Illegal usage of `pending`, prefer explicitly skipping a test using `test.skip`";
const illegal_jasmine = "Illegal usage of jasmine global";

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

    pub fn enter_call_expression(
        self: *Visitor,
        call_expression: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const callee = unwrapTransparent(ctx.tree, call_expression.callee);
        if (unresolvedIdentifierName(ctx.tree, self.symbol_table, callee)) |name| {
            if (std.mem.eql(u8, name, "spyOn") or std.mem.eql(u8, name, "spyOnProperty")) {
                try core.addDiagnosticFmt(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    ctx.tree.span(index),
                    "Illegal usage of global `{s}`, prefer `jest.spyOn`",
                    .{name},
                );
            } else if (std.mem.eql(u8, name, "fail")) {
                try core.addDiagnostic(self.allocator, self.diagnostics, .warning, id, illegal_fail, ctx.tree.span(index));
            } else if (std.mem.eql(u8, name, "pending")) {
                try core.addDiagnostic(self.allocator, self.diagnostics, .warning, id, illegal_pending, ctx.tree.span(index));
            }
            return .proceed;
        }

        const jasmine_call = jasmineCall(ctx.tree, callee) orelse return .proceed;
        if (jasmine_call.direct_method) |method| {
            if (expectReplacement(method)) |replacement| {
                const diagnostic_message = try std.fmt.allocPrint(
                    self.allocator,
                    "Illegal usage of `jasmine.{s}`, prefer `expect.{s}`",
                    .{ method, replacement },
                );
                defer self.allocator.free(diagnostic_message);
                try core.addDiagnosticWithFix(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    diagnostic_message,
                    ctx.tree.span(index),
                    .{ .span = jasmine_call.object_span, .replacement = "expect" },
                );
                return .proceed;
            }

            if (methodReplacement(method)) |replacement| {
                try core.addDiagnosticFmt(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    ctx.tree.span(index),
                    "Illegal usage of `jasmine.{s}`, prefer `{s}`",
                    .{ method, replacement },
                );
                return .proceed;
            }
        }

        try core.addDiagnostic(self.allocator, self.diagnostics, .warning, id, illegal_jasmine, ctx.tree.span(index));
        return .proceed;
    }

    pub fn enter_member_expression(
        self: *Visitor,
        member: ast.MemberExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (!isJasmineIdentifier(ctx.tree, member.object)) return .proceed;
        const parent_index = ctx.path.parent() orelse return .proceed;
        const assignment = switch (ctx.tree.data(parent_index)) {
            .assignment_expression => |value| value,
            else => return .proceed,
        };

        const property = staticPropertyName(ctx.tree, member.property, member.computed);
        if (property != null and
            std.mem.eql(u8, property.?, "DEFAULT_TIMEOUT_INTERVAL") and
            isLiteral(ctx.tree, assignment.right))
        {
            const replacement = try std.fmt.allocPrint(
                self.allocator,
                "jest.setTimeout({s})",
                .{ctx.tree.source[ctx.tree.span(assignment.right).start..ctx.tree.span(assignment.right).end]},
            );
            defer self.allocator.free(replacement);
            try core.addDiagnosticWithFix(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                illegal_jasmine,
                ctx.tree.span(index),
                .{ .span = ctx.tree.span(parent_index), .replacement = replacement },
            );
            return .proceed;
        }

        try core.addDiagnostic(self.allocator, self.diagnostics, .warning, id, illegal_jasmine, ctx.tree.span(index));
        return .proceed;
    }
};

const JasmineCall = struct {
    direct_method: ?[]const u8,
    object_span: ast.Span,
};

fn jasmineCall(tree: *const ast.Tree, callee: ast.NodeIndex) ?JasmineCall {
    const outer_member = switch (tree.data(callee)) {
        .member_expression => |value| value,
        else => return null,
    };
    const direct_method = staticPropertyName(tree, outer_member.property, outer_member.computed) orelse return null;
    const object_span = tree.span(outer_member.object);

    var object = unwrapTransparent(tree, outer_member.object);
    var depth: usize = 1;
    while (true) {
        switch (tree.data(object)) {
            .identifier_reference => |identifier| {
                if (!std.mem.eql(u8, tree.string(identifier.name), "jasmine")) return null;
                return .{
                    .direct_method = if (depth == 1) direct_method else null,
                    .object_span = object_span,
                };
            },
            .member_expression => |member| {
                _ = staticPropertyName(tree, member.property, member.computed) orelse return null;
                object = unwrapTransparent(tree, member.object);
                depth += 1;
            },
            else => return null,
        }
    }
}

fn expectReplacement(method: []const u8) ?[]const u8 {
    const methods = [_][]const u8{
        "any",
        "anything",
        "arrayContaining",
        "objectContaining",
        "stringMatching",
    };
    for (methods) |candidate| {
        if (std.mem.eql(u8, method, candidate)) return candidate;
    }
    return null;
}

fn methodReplacement(method: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, method, "addMatchers")) return "expect.extend";
    if (std.mem.eql(u8, method, "createSpy")) return "jest.fn";
    return null;
}

fn unresolvedIdentifierName(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) ?[]const u8 {
    const identifier = switch (tree.data(index)) {
        .identifier_reference => |value| value,
        else => return null,
    };
    if (!symbol_table.isUnresolvedReference(index)) return null;
    return tree.string(identifier.name);
}

fn isJasmineIdentifier(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "jasmine"),
        else => false,
    };
}

fn staticPropertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (!computed) {
        return switch (tree.data(index)) {
            .identifier_name => |identifier| tree.string(identifier.name),
            else => null,
        };
    }
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len != 1) return null;
    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn isLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal,
        .numeric_literal,
        .bigint_literal,
        .boolean_literal,
        .null_literal,
        .regexp_literal,
        => true,
        else => false,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |expression| current = expression.expression,
            .parenthesized_expression => |expression| current = expression.expression,
            .ts_as_expression => |expression| current = expression.expression,
            .ts_satisfies_expression => |expression| current = expression.expression,
            .ts_non_null_expression => |expression| current = expression.expression,
            .ts_type_assertion => |expression| current = expression.expression,
            else => return current,
        }
    }
    return current;
}
