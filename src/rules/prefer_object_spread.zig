const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "prefer-object-spread";

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
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isPreferableObjectAssign(ctx.tree, self.symbol_table, call)) {
            var fixes: std.ArrayList(core.Fix) = .empty;
            defer fixes.deinit(self.allocator);
            var replacements: std.ArrayList([]u8) = .empty;
            defer {
                for (replacements.items) |replacement| self.allocator.free(replacement);
                replacements.deinit(self.allocator);
            }

            if (try buildFixes(self.allocator, &fixes, &replacements, ctx.tree, call, index, ctx.path.parent())) {
                try core.addDiagnosticWithFixes(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    "Use an object spread instead of Object.assign.",
                    ctx.tree.span(index),
                    fixes.items,
                );
            } else {
                try core.addDiagnostic(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    "Use an object spread instead of Object.assign.",
                    ctx.tree.span(index),
                );
            }
        }

        return .proceed;
    }
};

fn buildFixes(
    allocator: Allocator,
    fixes: *std.ArrayList(core.Fix),
    replacements: *std.ArrayList([]u8),
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    parent: ?ast.NodeIndex,
) Allocator.Error!bool {
    const arguments = tree.extra(call.arguments);
    const call_span = tree.span(index);
    const first_span = tree.span(arguments[0]);
    const open_search_start = if (call.type_arguments != .null)
        tree.span(call.type_arguments).end
    else
        tree.span(call.callee).end;
    const open_paren = findByteOutsideComments(tree, open_search_start, first_span.start, '(') orelse return false;
    const close_paren = findLastByteOutsideComments(tree, first_span.end, call_span.end, ')') orelse return false;
    const add_parens = needsParens(tree, index, parent);

    try fixes.append(allocator, .{
        .span = .{ .start = call_span.start, .end = open_paren },
        .replacement = "",
    });
    try fixes.append(allocator, .{
        .span = .{ .start = open_paren, .end = open_paren + 1 },
        .replacement = if (add_parens) "({" else "{",
    });
    try fixes.append(allocator, .{
        .span = .{ .start = close_paren, .end = close_paren + 1 },
        .replacement = if (add_parens) "})" else "}",
    });

    var previous_had_properties = false;
    var previous_had_trailing_comma = false;
    for (arguments, 0..) |argument, argument_index| {
        if (argument_index > 0 and (!previous_had_properties or previous_had_trailing_comma)) {
            const previous_span = tree.span(arguments[argument_index - 1]);
            const argument_span = tree.span(argument);
            const comma = findByteOutsideComments(tree, previous_span.end, argument_span.start, ',') orelse return false;
            try fixes.append(allocator, .{
                .span = .{ .start = comma, .end = comma + 1 },
                .replacement = "",
            });
        }

        if (objectExpression(tree, argument)) |object_index| {
            const argument_span = tree.span(argument);
            const object_span = tree.span(object_index);
            if (object_span.end <= object_span.start + 1) return false;
            const left_end = skipWhitespaceForward(tree.source, object_span.start + 1, object_span.end - 1);
            const right_start = @max(
                skipWhitespaceBackwardUnlessLineComment(tree, left_end, object_span.end - 1),
                left_end,
            );

            try fixes.append(allocator, .{
                .span = .{ .start = object_span.start, .end = left_end },
                .replacement = "",
            });
            try fixes.append(allocator, .{
                .span = .{ .start = right_start, .end = object_span.end },
                .replacement = "",
            });
            try appendByteRemovalsOutsideComments(allocator, fixes, tree, argument_span.start, object_span.start, '(');
            try appendByteRemovalsOutsideComments(allocator, fixes, tree, object_span.end, argument_span.end, ')');

            const object = tree.data(object_index).object_expression;
            previous_had_properties = object.properties.len > 0;
            previous_had_trailing_comma = previous_had_properties and
                hasTrailingComma(tree, object, object_span);
        } else {
            const argument_span = tree.span(argument);
            const argument_source = tree.source[argument_span.start..argument_span.end];
            const replacement = if (argumentNeedsParens(tree, argument))
                try std.fmt.allocPrint(allocator, "...({s})", .{argument_source})
            else
                try std.fmt.allocPrint(allocator, "...{s}", .{argument_source});
            replacements.append(allocator, replacement) catch |err| {
                allocator.free(replacement);
                return err;
            };
            try fixes.append(allocator, .{ .span = argument_span, .replacement = replacement });
            previous_had_properties = true;
            previous_had_trailing_comma = false;
        }
    }

    return true;
}

fn needsParens(tree: *const ast.Tree, index: ast.NodeIndex, parent: ?ast.NodeIndex) bool {
    const parent_index = parent orelse return true;
    return switch (tree.data(parent_index)) {
        .variable_declarator => |declarator| declarator.init != index,
        .array_expression,
        .return_statement,
        .call_expression,
        .parenthesized_expression,
        => false,
        .object_property => |property| property.value != index,
        .assignment_expression => |assignment| assignment.left == index,
        else => true,
    };
}

fn argumentNeedsParens(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .assignment_expression, .arrow_function_expression, .conditional_expression => true,
        else => false,
    };
}

fn objectExpression(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    const unwrapped = unwrapTransparent(tree, index);
    return if (tree.data(unwrapped) == .object_expression) unwrapped else null;
}

fn hasTrailingComma(tree: *const ast.Tree, object: ast.ObjectExpression, span: ast.Span) bool {
    const properties = tree.extra(object.properties);
    if (properties.len == 0) return false;
    return findByteOutsideComments(tree, tree.span(properties[properties.len - 1]).end, span.end - 1, ',') != null;
}

fn findByte(source: []const u8, start: u32, end: u32, byte: u8) ?u32 {
    const relative = std.mem.indexOfScalar(u8, source[start..end], byte) orelse return null;
    return start + @as(u32, @intCast(relative));
}

fn findByteOutsideComments(tree: *const ast.Tree, start: u32, end: u32, byte: u8) ?u32 {
    var search_start = start;
    while (findByte(tree.source, search_start, end, byte)) |offset| {
        if (!hasCommentAt(tree, offset)) return offset;
        search_start = offset + 1;
    }
    return null;
}

fn findLastByteOutsideComments(tree: *const ast.Tree, start: u32, end: u32, byte: u8) ?u32 {
    var result: ?u32 = null;
    var search_start = start;
    while (findByteOutsideComments(tree, search_start, end, byte)) |offset| {
        result = offset;
        search_start = offset + 1;
    }
    return result;
}

fn appendByteRemovalsOutsideComments(
    allocator: Allocator,
    fixes: *std.ArrayList(core.Fix),
    tree: *const ast.Tree,
    start: u32,
    end: u32,
    byte: u8,
) Allocator.Error!void {
    var search_start = start;
    while (findByteOutsideComments(tree, search_start, end, byte)) |offset| {
        try fixes.append(allocator, .{
            .span = .{ .start = offset, .end = offset + 1 },
            .replacement = "",
        });
        search_start = offset + 1;
    }
}

fn hasCommentAt(tree: *const ast.Tree, offset: u32) bool {
    for (tree.comments) |comment| {
        if (comment.span.end <= offset) continue;
        if (comment.span.start > offset) break;
        return true;
    }
    return false;
}

fn skipWhitespaceForward(source: []const u8, start: u32, end: u32) u32 {
    var offset = start;
    while (offset < end and std.ascii.isWhitespace(source[offset])) : (offset += 1) {}
    return offset;
}

fn skipWhitespaceBackwardUnlessLineComment(tree: *const ast.Tree, start: u32, end: u32) u32 {
    for (tree.comments) |comment| {
        if (comment.type != .line or comment.span.end > end or comment.span.end < start) continue;
        if (onlyWhitespace(tree.source, comment.span.end, end)) return end;
    }

    var offset = end;
    while (offset > start and std.ascii.isWhitespace(tree.source[offset - 1])) : (offset -= 1) {}
    return offset;
}

fn onlyWhitespace(source: []const u8, start: u32, end: u32) bool {
    for (source[start..end]) |byte| {
        if (!std.ascii.isWhitespace(byte)) return false;
    }
    return true;
}

fn isPreferableObjectAssign(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    call: ast.CallExpression,
) bool {
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return false;
    if (!isObjectExpression(tree, arguments[0])) return false;
    for (arguments[1..]) |argument| {
        if (tree.data(argument) == .spread_element) return false;
    }
    if (arguments.len > 1 and hasArgumentsWithAccessors(tree, arguments)) return false;
    return isGlobalObjectAssign(tree, symbol_table, call.callee);
}

fn hasArgumentsWithAccessors(tree: *const ast.Tree, arguments: []const ast.NodeIndex) bool {
    for (arguments) |argument| {
        const object_index = objectExpression(tree, argument) orelse continue;
        const properties = tree.extra(tree.data(object_index).object_expression.properties);
        for (properties) |property_index| {
            const property = switch (tree.data(property_index)) {
                .object_property => |property| property,
                else => continue,
            };
            if (property.kind == .get or property.kind == .set) return true;
        }
    }
    return false;
}

fn isObjectExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .object_expression => true,
        else => false,
    };
}

fn isGlobalObjectAssign(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    const member = switch (tree.data(unwrapped)) {
        .member_expression => |member| member,
        else => return false,
    };
    const property_name = memberPropertyName(tree, member) orelse return false;
    if (!std.mem.eql(u8, property_name, "assign")) return false;
    const object = unwrapTransparent(tree, member.object);
    if (!isIdentifierReference(tree, object, "Object")) return false;
    return isUnresolvedReference(symbol_table, object);
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

fn memberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    if (!member.computed) {
        return switch (tree.data(member.property)) {
            .identifier_name => |identifier| tree.string(identifier.name),
            else => null,
        };
    }

    return switch (tree.data(unwrapTransparent(tree, member.property))) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";
    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn isIdentifierReference(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), expected),
        else => false,
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
