const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const jest_fn_call = @import("jest_fn_call.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "jest/no-standalone-expect";

const message = "Expect must be inside of a test block";

const MarkerKind = enum {
    test_case,
    function,
    describe,
};

const Marker = struct {
    node: ast.NodeIndex,
    kind: MarkerKind,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    global_aliases: core.JestGlobalAliases,
    additional_test_block_functions: core.JestAdditionalTestBlockFunctions,
) Allocator.Error!void {
    var resolver = try jest_fn_call.Resolver.init(allocator, tree, symbol_table, global_aliases);
    defer resolver.deinit();

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .resolver = &resolver,
        .additional_test_block_functions = additional_test_block_functions,
    };
    defer visitor.markers.deinit(allocator);
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    resolver: *const jest_fn_call.Resolver,
    additional_test_block_functions: core.JestAdditionalTestBlockFunctions,
    markers: std.ArrayList(Marker) = .empty,

    pub fn enter_call_expression(
        self: *Visitor,
        call_expression: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.resolver.parseCall(call_expression, index, ctx.path.parent())) |call| {
            switch (call.function.kind()) {
                .expect => {
                    if (isAllowedStandaloneMethod(call)) return .proceed;
                    if (!self.expectIsAllowed()) {
                        try core.addDiagnostic(
                            self.allocator,
                            self.diagnostics,
                            .warning,
                            id,
                            message,
                            ctx.tree.span(index),
                        );
                    }
                    return .proceed;
                },
                .test_case => {
                    try self.markers.append(self.allocator, .{ .node = index, .kind = .test_case });
                    return .proceed;
                },
                .describe => {},
            }
        }

        if (matchesAdditionalTestBlockFunction(
            ctx.tree,
            index,
            self.additional_test_block_functions,
        )) {
            try self.markers.append(self.allocator, .{ .node = index, .kind = .test_case });
        }
        return .proceed;
    }

    pub fn exit_call_expression(
        self: *Visitor,
        _: ast.CallExpression,
        index: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        self.popMarker(index);
    }

    pub fn enter_function(
        self: *Visitor,
        function: ast.Function,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const parent = ctx.path.ancestor(1) orelse .null;
        if (self.callbackMarker(ctx.tree, index, parent, ctx.path.ancestor(2))) |kind| {
            try self.markers.append(self.allocator, .{ .node = index, .kind = kind });
        } else if (function.type == .function_declaration or isVariableInitializer(ctx.tree, index, parent)) {
            try self.markers.append(self.allocator, .{ .node = index, .kind = .function });
        }
        return .proceed;
    }

    pub fn exit_function(
        self: *Visitor,
        _: ast.Function,
        index: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        self.popMarker(index);
    }

    pub fn enter_arrow_function_expression(
        self: *Visitor,
        _: ast.ArrowFunctionExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const parent = ctx.path.ancestor(1) orelse .null;
        if (self.callbackMarker(ctx.tree, index, parent, ctx.path.ancestor(2))) |kind| {
            try self.markers.append(self.allocator, .{ .node = index, .kind = kind });
        } else if (!isCallExpression(ctx.tree, parent)) {
            try self.markers.append(self.allocator, .{ .node = index, .kind = .function });
        }
        return .proceed;
    }

    pub fn exit_arrow_function_expression(
        self: *Visitor,
        _: ast.ArrowFunctionExpression,
        index: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        self.popMarker(index);
    }

    fn callbackMarker(
        self: *Visitor,
        tree: *const ast.Tree,
        function_index: ast.NodeIndex,
        parent_index: ast.NodeIndex,
        grandparent_index: ?ast.NodeIndex,
    ) ?MarkerKind {
        const parent_call = switch (tree.data(parent_index)) {
            .call_expression => |call| call,
            else => return null,
        };
        if (!isCallArgument(tree, parent_call, function_index)) return null;

        const parsed = self.resolver.parseCall(parent_call, parent_index, grandparent_index);
        if (parsed) |call| {
            return switch (call.function.kind()) {
                .describe => .describe,
                .test_case => null,
                .expect => null,
            };
        }
        return null;
    }

    fn expectIsAllowed(self: *const Visitor) bool {
        if (self.markers.items.len == 0) return false;
        return self.markers.items[self.markers.items.len - 1].kind != .describe;
    }

    fn popMarker(self: *Visitor, index: ast.NodeIndex) void {
        if (self.markers.items.len == 0) return;
        if (self.markers.items[self.markers.items.len - 1].node == index) {
            _ = self.markers.pop();
        }
    }
};

fn isAllowedStandaloneMethod(call: jest_fn_call.Call) bool {
    if (call.nested_calls != 0 or call.member_count != 1) return false;
    const member = call.members[0].name;
    return !std.mem.eql(u8, member, "assertions") and
        !std.mem.eql(u8, member, "hasAssertions");
}

fn isVariableInitializer(tree: *const ast.Tree, index: ast.NodeIndex, parent_index: ast.NodeIndex) bool {
    return switch (tree.data(parent_index)) {
        .variable_declarator => |declarator| declarator.init == index,
        else => false,
    };
}

fn isCallExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return tree.data(index) == .call_expression;
}

fn isCallArgument(tree: *const ast.Tree, call: ast.CallExpression, index: ast.NodeIndex) bool {
    for (tree.extra(call.arguments)) |argument| {
        if (argument == index) return true;
    }
    return false;
}

fn matchesAdditionalTestBlockFunction(
    tree: *const ast.Tree,
    call_index: ast.NodeIndex,
    configured: core.JestAdditionalTestBlockFunctions,
) bool {
    if (configured.count == 0) return false;

    var buffer: [core.max_jest_additional_test_block_function_len]u8 = undefined;
    var length: usize = 0;
    if (!writeNodeName(tree, call_index, &buffer, &length)) return false;
    const name = buffer[0..length];
    for (0..configured.count) |index| {
        if (std.mem.eql(u8, configured.at(index), name)) return true;
    }
    return false;
}

fn writeNodeName(
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    buffer: *[core.max_jest_additional_test_block_function_len]u8,
    length: *usize,
) bool {
    const current = unwrapTransparent(tree, index);
    return switch (tree.data(current)) {
        .identifier_reference => |identifier| appendName(buffer, length, tree.string(identifier.name)),
        .call_expression => |call| writeNodeName(tree, call.callee, buffer, length),
        .tagged_template_expression => |tagged| writeNodeName(tree, tagged.tag, buffer, length),
        .member_expression => |member| blk: {
            if (!writeNodeName(tree, member.object, buffer, length)) break :blk false;
            const property = staticPropertyName(tree, member.property, member.computed) orelse break :blk false;
            if (!appendName(buffer, length, ".")) break :blk false;
            break :blk appendName(buffer, length, property);
        },
        else => false,
    };
}

fn appendName(
    buffer: *[core.max_jest_additional_test_block_function_len]u8,
    length: *usize,
    value: []const u8,
) bool {
    if (value.len > buffer.len - length.*) return false;
    @memcpy(buffer[length.* .. length.* + value.len], value);
    length.* += value.len;
    return true;
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
