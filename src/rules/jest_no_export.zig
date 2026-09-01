const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "jest/no-export";

const message = "Do not export from a test file";

const JestFunction = enum {
    describe,
    fdescribe,
    xdescribe,
    test_case,
    xtest,
    it,
    fit,
    xit,
};

const ImportedGlobals = std.StringHashMapUnmanaged(JestFunction);

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var imported_globals: ImportedGlobals = .empty;
    defer imported_globals.deinit(allocator);
    try collectImportedGlobals(allocator, tree, &imported_globals);

    var export_nodes: std.ArrayList(ast.NodeIndex) = .empty;
    defer export_nodes.deinit(allocator);

    var visitor = Visitor{
        .allocator = allocator,
        .symbol_table = symbol_table,
        .imported_globals = &imported_globals,
        .export_nodes = &export_nodes,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);

    if (!visitor.has_test_case) return;
    for (export_nodes.items) |index| {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            message,
            tree.span(index),
        );
    }
}

const Visitor = struct {
    allocator: Allocator,
    symbol_table: traverser.semantic.SymbolTable,
    imported_globals: *const ImportedGlobals,
    export_nodes: *std.ArrayList(ast.NodeIndex),
    has_test_case: bool = false,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (!isTopmostCall(ctx.tree, index, ctx.path.parent())) return .proceed;

        var chain: JestCalleeChain = .{};
        if (!collectJestCalleeChain(ctx.tree, call.callee, &chain)) return .proceed;
        const root = chain.root;
        const name = identifierName(ctx.tree, root) orelse return .proceed;
        const reference_id = self.symbol_table.model.referenceOf(root) orelse return .proceed;
        const symbol_id = self.symbol_table.referenceSymbol(reference_id);

        const jest_function: JestFunction = if (symbol_id == .none) blk: {
            break :blk jestFunctionForName(name) orelse return .proceed;
        } else blk: {
            const symbol = self.symbol_table.getSymbol(symbol_id);
            if (!symbol.flags.import) return .proceed;
            break :blk self.imported_globals.get(self.symbol_table.tree.string(symbol.name)) orelse return .proceed;
        };

        if (!isValidJestCall(jest_function, chain)) return .proceed;

        self.has_test_case = true;
        return .proceed;
    }

    pub fn enter_export_named_declaration(
        self: *Visitor,
        _: ast.ExportNamedDeclaration,
        index: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.export_nodes.append(self.allocator, index);
        return .proceed;
    }

    pub fn enter_export_default_declaration(
        self: *Visitor,
        _: ast.ExportDefaultDeclaration,
        index: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.export_nodes.append(self.allocator, index);
        return .proceed;
    }

    pub fn enter_ts_export_assignment(
        self: *Visitor,
        _: ast.TSExportAssignment,
        index: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.export_nodes.append(self.allocator, index);
        return .proceed;
    }

    pub fn enter_assignment_expression(
        self: *Visitor,
        assignment: ast.AssignmentExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const left = unwrapTransparent(ctx.tree, assignment.left);
        const outer_member = switch (ctx.tree.data(left)) {
            .member_expression => |member| member,
            else => return .proceed,
        };

        var object = unwrapTransparent(ctx.tree, outer_member.object);
        var root_property = outer_member.property;
        while (true) {
            const member = switch (ctx.tree.data(object)) {
                .member_expression => |value| value,
                else => break,
            };
            root_property = member.property;
            object = unwrapTransparent(ctx.tree, member.object);
        }

        const root_name = identifierName(ctx.tree, object) orelse return .proceed;
        const reference_id = self.symbol_table.model.referenceOf(object) orelse return .proceed;
        if (self.symbol_table.referenceSymbol(reference_id) != .none) return .proceed;

        if (std.mem.eql(u8, root_name, "exports")) {
            try self.export_nodes.append(self.allocator, left);
            return .proceed;
        }
        if (!std.mem.eql(u8, root_name, "module")) return .proceed;

        const property_name = staticPropertyName(ctx.tree, root_property) orelse return .proceed;
        if (std.mem.eql(u8, property_name, "exports") or std.mem.eql(u8, property_name, "export")) {
            try self.export_nodes.append(self.allocator, left);
        }
        return .proceed;
    }
};

fn collectImportedGlobals(
    allocator: Allocator,
    tree: *const ast.Tree,
    imported_globals: *ImportedGlobals,
) Allocator.Error!void {
    const program = switch (tree.data(tree.root)) {
        .program => |value| value,
        else => return,
    };

    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |value| value,
            else => continue,
        };
        if (declaration.import_kind == .type) continue;
        const source = stringLiteralValue(tree, declaration.source) orelse continue;
        if (!std.mem.eql(u8, source, "@jest/globals")) continue;

        for (tree.extra(declaration.specifiers)) |specifier_index| {
            const specifier = switch (tree.data(specifier_index)) {
                .import_specifier => |value| value,
                else => continue,
            };
            if (specifier.import_kind == .type) continue;
            const imported = propertyNodeName(tree, specifier.imported) orelse continue;
            const jest_function = jestFunctionForName(imported) orelse continue;
            const local = bindingIdentifierName(tree, specifier.local) orelse continue;
            try imported_globals.put(allocator, local, jest_function);
        }
    }
}

const JestCalleeChain = struct {
    root: ast.NodeIndex = .null,
    members: [4][]const u8 = undefined,
    member_count: usize = 0,
    nested_calls: usize = 0,
    tagged_templates: usize = 0,

    fn append(self: *JestCalleeChain, member: []const u8) bool {
        if (self.member_count == self.members.len) return false;
        self.members[self.member_count] = member;
        self.member_count += 1;
        return true;
    }

    fn memberSlice(self: *const JestCalleeChain) []const []const u8 {
        return self.members[0..self.member_count];
    }
};

fn collectJestCalleeChain(tree: *const ast.Tree, index: ast.NodeIndex, chain: *JestCalleeChain) bool {
    const current = unwrapTransparent(tree, index);
    return switch (tree.data(current)) {
        .identifier_reference => blk: {
            if (chain.root != .null) break :blk false;
            chain.root = current;
            break :blk true;
        },
        .member_expression => |member| blk: {
            if (!collectJestCalleeChain(tree, member.object, chain)) break :blk false;
            const property = staticPropertyName(tree, member.property) orelse break :blk false;
            break :blk chain.append(property);
        },
        .call_expression => |call| {
            chain.nested_calls += 1;
            return collectJestCalleeChain(tree, call.callee, chain);
        },
        .tagged_template_expression => |tagged| {
            chain.tagged_templates += 1;
            return collectJestCalleeChain(tree, tagged.tag, chain);
        },
        else => return false,
    };
}

fn isTopmostCall(tree: *const ast.Tree, index: ast.NodeIndex, parent: ?ast.NodeIndex) bool {
    const parent_index = parent orelse return true;
    return switch (tree.data(parent_index)) {
        .call_expression => |call| unwrapTransparent(tree, call.callee) != index,
        .member_expression => |member| unwrapTransparent(tree, member.object) != index,
        .tagged_template_expression => |tagged| unwrapTransparent(tree, tagged.tag) != index,
        else => true,
    };
}

fn isValidJestCall(jest_function: JestFunction, chain: JestCalleeChain) bool {
    const members = chain.memberSlice();
    const ends_in_each = members.len != 0 and std.mem.eql(u8, members[members.len - 1], "each");

    if (ends_in_each) {
        if (chain.nested_calls + chain.tagged_templates != 1) return false;
    } else if (chain.nested_calls != 0 or chain.tagged_templates != 0) {
        return false;
    }

    return switch (jest_function) {
        .describe => matchesMembers(members, &.{}) or
            matchesMembers(members, &.{"each"}) or
            matchesMembers(members, &.{"only"}) or
            matchesMembers(members, &.{ "only", "each" }) or
            matchesMembers(members, &.{"skip"}) or
            matchesMembers(members, &.{ "skip", "each" }),
        .fdescribe, .xdescribe => matchesMembers(members, &.{}) or
            matchesMembers(members, &.{"each"}),
        .test_case, .it => matchesMembers(members, &.{}) or
            matchesMembers(members, &.{"todo"}) or
            matchesMembers(members, &.{"each"}) or
            matchesMembers(members, &.{"failing"}) or
            matchesMembers(members, &.{ "failing", "each" }) or
            matchesMembers(members, &.{"only"}) or
            matchesMembers(members, &.{ "only", "each" }) or
            matchesMembers(members, &.{ "only", "failing" }) or
            matchesMembers(members, &.{ "only", "failing", "each" }) or
            matchesMembers(members, &.{"skip"}) or
            matchesMembers(members, &.{ "skip", "each" }) or
            matchesMembers(members, &.{ "skip", "failing" }) or
            matchesMembers(members, &.{ "skip", "failing", "each" }) or
            matchesMembers(members, &.{"concurrent"}) or
            matchesMembers(members, &.{ "concurrent", "each" }) or
            matchesMembers(members, &.{ "concurrent", "failing" }) or
            matchesMembers(members, &.{ "concurrent", "failing", "each" }) or
            matchesMembers(members, &.{ "concurrent", "failing", "only", "each" }) or
            matchesMembers(members, &.{ "concurrent", "failing", "skip", "each" }) or
            matchesMembers(members, &.{ "concurrent", "only", "each" }) or
            matchesMembers(members, &.{ "concurrent", "skip", "each" }),
        .xtest, .fit, .xit => matchesMembers(members, &.{}) or
            matchesMembers(members, &.{"each"}) or
            matchesMembers(members, &.{"failing"}) or
            matchesMembers(members, &.{ "failing", "each" }),
    };
}

fn matchesMembers(actual: []const []const u8, expected: []const []const u8) bool {
    if (actual.len != expected.len) return false;
    for (actual, expected) |actual_member, expected_member| {
        if (!std.mem.eql(u8, actual_member, expected_member)) return false;
    }
    return true;
}

fn jestFunctionForName(name: []const u8) ?JestFunction {
    if (std.mem.eql(u8, name, "describe")) return .describe;
    if (std.mem.eql(u8, name, "fdescribe")) return .fdescribe;
    if (std.mem.eql(u8, name, "xdescribe")) return .xdescribe;
    if (std.mem.eql(u8, name, "test")) return .test_case;
    if (std.mem.eql(u8, name, "xtest")) return .xtest;
    if (std.mem.eql(u8, name, "it")) return .it;
    if (std.mem.eql(u8, name, "fit")) return .fit;
    if (std.mem.eql(u8, name, "xit")) return .xit;
    return null;
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn propertyNodeName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn staticPropertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
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
