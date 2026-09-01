const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const Function = enum {
    describe,
    fdescribe,
    xdescribe,
    test_case,
    xtest,
    it,
    fit,
    xit,
    expect,

    pub fn canonicalName(self: Function) []const u8 {
        return switch (self) {
            .describe => "describe",
            .fdescribe => "fdescribe",
            .xdescribe => "xdescribe",
            .test_case => "test",
            .xtest => "xtest",
            .it => "it",
            .fit => "fit",
            .xit => "xit",
            .expect => "expect",
        };
    }

    pub fn kind(self: Function) Kind {
        return switch (self) {
            .describe, .fdescribe, .xdescribe => .describe,
            .test_case, .xtest, .it, .fit, .xit => .test_case,
            .expect => .expect,
        };
    }

    pub fn isFocused(self: Function) bool {
        return self == .fdescribe or self == .fit;
    }
};

pub const Kind = enum {
    describe,
    test_case,
    expect,
};

pub const Origin = enum {
    global,
    import,
    require,
};

pub const Member = struct {
    name: []const u8,
    node: ast.NodeIndex,
    computed: bool,
    accessor_span: ast.Span,
};

pub const Call = struct {
    function: Function,
    origin: Origin,
    head: ast.NodeIndex,
    local_name: []const u8,
    members: [4]Member = undefined,
    member_count: usize = 0,

    pub fn memberSlice(self: *const Call) []const Member {
        return self.members[0..self.member_count];
    }

    pub fn memberNamed(self: *const Call, name: []const u8) ?Member {
        for (self.memberSlice()) |member| {
            if (std.mem.eql(u8, member.name, name)) return member;
        }
        return null;
    }

    pub fn lastMember(self: *const Call) ?Member {
        if (self.member_count == 0) return null;
        return self.members[self.member_count - 1];
    }

    pub fn usesCanonicalName(self: *const Call) bool {
        return std.mem.eql(u8, self.function.canonicalName(), self.local_name);
    }
};

const Binding = struct {
    function: Function,
    origin: Origin,
    local_name: []const u8,
};

const BindingMap = std.AutoHashMapUnmanaged(traverser.semantic.SymbolId, Binding);

pub const Resolver = struct {
    allocator: Allocator,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    global_aliases: core.JestGlobalAliases,
    bindings: BindingMap = .empty,

    pub fn init(
        allocator: Allocator,
        tree: *const ast.Tree,
        symbol_table: traverser.semantic.SymbolTable,
        global_aliases: core.JestGlobalAliases,
    ) Allocator.Error!Resolver {
        var resolver = Resolver{
            .allocator = allocator,
            .tree = tree,
            .symbol_table = symbol_table,
            .global_aliases = global_aliases,
        };
        errdefer resolver.deinit();
        try resolver.collectBindings();
        return resolver;
    }

    pub fn deinit(self: *Resolver) void {
        self.bindings.deinit(self.allocator);
    }

    pub fn parseCall(
        self: *const Resolver,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        parent: ?ast.NodeIndex,
    ) ?Call {
        if (!isTopmostCall(self.tree, index, parent)) return null;

        var chain: CalleeChain = .{};
        if (!collectCalleeChain(self.tree, call.callee, &chain)) return null;
        const local_name = identifierName(self.tree, chain.root) orelse return null;
        const reference_id = self.symbol_table.model.referenceOf(chain.root) orelse return null;
        const symbol_id = self.symbol_table.referenceSymbol(reference_id);

        const binding: Binding = if (symbol_id == .none) blk: {
            const canonical_name = self.global_aliases.canonicalFor(local_name) orelse local_name;
            break :blk .{
                .function = functionForName(canonical_name) orelse return null,
                .origin = .global,
                .local_name = local_name,
            };
        } else self.bindings.get(symbol_id) orelse return null;

        if (!isValidCall(binding.function, chain)) return null;

        var result = Call{
            .function = binding.function,
            .origin = binding.origin,
            .head = chain.root,
            .local_name = binding.local_name,
            .member_count = chain.member_count,
        };
        @memcpy(result.members[0..chain.member_count], chain.members[0..chain.member_count]);
        return result;
    }

    fn collectBindings(self: *Resolver) Allocator.Error!void {
        const program = switch (self.tree.data(self.tree.root)) {
            .program => |value| value,
            else => return,
        };

        for (self.tree.extra(program.body)) |statement_index| {
            switch (self.tree.data(statement_index)) {
                .import_declaration => |declaration| try self.collectImportDeclaration(declaration),
                else => {},
            }
        }

        var visitor = BindingCollector{ .resolver = self };
        try traverser.basic.traverse(BindingCollector, self.tree, &visitor);
    }

    fn collectImportDeclaration(self: *Resolver, declaration: ast.ImportDeclaration) Allocator.Error!void {
        if (declaration.import_kind == .type) return;
        const source = stringLiteralValue(self.tree, declaration.source) orelse return;
        if (!std.mem.eql(u8, source, "@jest/globals")) return;

        for (self.tree.extra(declaration.specifiers)) |specifier_index| {
            const specifier = switch (self.tree.data(specifier_index)) {
                .import_specifier => |value| value,
                else => continue,
            };
            if (specifier.import_kind == .type) continue;
            const imported = propertyNodeName(self.tree, specifier.imported) orelse continue;
            const function = functionForName(imported) orelse continue;
            const local_name = bindingIdentifierName(self.tree, specifier.local) orelse continue;
            const symbol_id = self.symbol_table.symbolOf(specifier.local) orelse continue;
            try self.bindings.put(self.allocator, symbol_id, .{
                .function = function,
                .origin = .import,
                .local_name = local_name,
            });
        }
    }

    fn collectRequireDeclarator(self: *Resolver, declarator: ast.VariableDeclarator) Allocator.Error!void {
        const pattern = switch (self.tree.data(declarator.id)) {
            .object_pattern => |value| value,
            else => return,
        };
        const call_index = unwrapTransparent(self.tree, declarator.init);
        const call = switch (self.tree.data(call_index)) {
            .call_expression => |value| value,
            else => return,
        };
        const callee = unwrapTransparent(self.tree, call.callee);
        const callee_name = identifierName(self.tree, callee) orelse return;
        if (!std.mem.eql(u8, callee_name, "require")) return;
        if (!self.symbol_table.isUnresolvedReference(callee)) return;
        const arguments = self.tree.extra(call.arguments);
        if (arguments.len != 1) return;
        const source = stringLiteralValue(self.tree, arguments[0]) orelse return;
        if (!std.mem.eql(u8, source, "@jest/globals")) return;

        for (self.tree.extra(pattern.properties)) |property_index| {
            const property = switch (self.tree.data(property_index)) {
                .binding_property => |value| value,
                else => continue,
            };
            if (property.computed) continue;
            const imported = propertyNodeName(self.tree, property.key) orelse continue;
            const function = functionForName(imported) orelse continue;
            const local_name = bindingIdentifierName(self.tree, property.value) orelse continue;
            const symbol_id = self.symbol_table.symbolOf(property.value) orelse continue;
            try self.bindings.put(self.allocator, symbol_id, .{
                .function = function,
                .origin = .require,
                .local_name = local_name,
            });
        }
    }
};

const BindingCollector = struct {
    resolver: *Resolver,

    pub fn enter_variable_declarator(
        self: *BindingCollector,
        declarator: ast.VariableDeclarator,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.resolver.collectRequireDeclarator(declarator);
        return .proceed;
    }
};

const CalleeChain = struct {
    root: ast.NodeIndex = .null,
    members: [4]Member = undefined,
    member_count: usize = 0,
    nested_calls: usize = 0,
    tagged_templates: usize = 0,

    fn append(self: *CalleeChain, member: Member) bool {
        if (self.member_count == self.members.len) return false;
        self.members[self.member_count] = member;
        self.member_count += 1;
        return true;
    }

    fn memberSlice(self: *const CalleeChain) []const Member {
        return self.members[0..self.member_count];
    }
};

fn collectCalleeChain(tree: *const ast.Tree, index: ast.NodeIndex, chain: *CalleeChain) bool {
    const current = unwrapTransparent(tree, index);
    return switch (tree.data(current)) {
        .identifier_reference => blk: {
            if (chain.root != .null) break :blk false;
            chain.root = current;
            break :blk true;
        },
        .member_expression => |member| blk: {
            if (!collectCalleeChain(tree, member.object, chain)) break :blk false;
            const property = staticPropertyName(tree, member.property) orelse break :blk false;
            const accessor_start = memberAccessorStart(tree, member) orelse break :blk false;
            break :blk chain.append(.{
                .name = property,
                .node = member.property,
                .computed = member.computed,
                .accessor_span = .{ .start = @intCast(accessor_start), .end = tree.span(current).end },
            });
        },
        .call_expression => |call| {
            chain.nested_calls += 1;
            return collectCalleeChain(tree, call.callee, chain);
        },
        .tagged_template_expression => |tagged| {
            chain.tagged_templates += 1;
            return collectCalleeChain(tree, tagged.tag, chain);
        },
        else => false,
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

fn isValidCall(function: Function, chain: CalleeChain) bool {
    if (function == .expect) return isValidExpectCall(chain);

    const members = chain.memberSlice();
    const ends_in_each = members.len != 0 and std.mem.eql(u8, members[members.len - 1].name, "each");

    if (ends_in_each) {
        if (chain.nested_calls + chain.tagged_templates != 1) return false;
    } else if (chain.nested_calls != 0 or chain.tagged_templates != 0) {
        return false;
    }

    return switch (function) {
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
            matchesMembers(members, &.{ "concurrent", "failing", "only" }) or
            matchesMembers(members, &.{ "concurrent", "failing", "only", "each" }) or
            matchesMembers(members, &.{ "concurrent", "failing", "skip", "each" }) or
            matchesMembers(members, &.{ "concurrent", "only" }) or
            matchesMembers(members, &.{ "concurrent", "only", "each" }) or
            matchesMembers(members, &.{ "concurrent", "skip", "each" }),
        .xtest, .fit, .xit => matchesMembers(members, &.{}) or
            matchesMembers(members, &.{"each"}) or
            matchesMembers(members, &.{"failing"}) or
            matchesMembers(members, &.{ "failing", "each" }),
        .expect => unreachable,
    };
}

fn isValidExpectCall(chain: CalleeChain) bool {
    if (chain.tagged_templates != 0 or chain.nested_calls > 1) return false;
    const members = chain.memberSlice();
    if (members.len == 0) return chain.nested_calls == 0;

    const modifiers = members[0 .. members.len - 1];
    return switch (modifiers.len) {
        0 => true,
        1 => std.mem.eql(u8, modifiers[0].name, "not") or
            std.mem.eql(u8, modifiers[0].name, "resolves") or
            std.mem.eql(u8, modifiers[0].name, "rejects"),
        2 => (std.mem.eql(u8, modifiers[0].name, "resolves") or
            std.mem.eql(u8, modifiers[0].name, "rejects")) and
            std.mem.eql(u8, modifiers[1].name, "not"),
        else => false,
    };
}

fn matchesMembers(actual: []const Member, expected: []const []const u8) bool {
    if (actual.len != expected.len) return false;
    for (actual, expected) |actual_member, expected_member| {
        if (!std.mem.eql(u8, actual_member.name, expected_member)) return false;
    }
    return true;
}

fn functionForName(name: []const u8) ?Function {
    if (std.mem.eql(u8, name, "describe")) return .describe;
    if (std.mem.eql(u8, name, "fdescribe")) return .fdescribe;
    if (std.mem.eql(u8, name, "xdescribe")) return .xdescribe;
    if (std.mem.eql(u8, name, "test")) return .test_case;
    if (std.mem.eql(u8, name, "xtest")) return .xtest;
    if (std.mem.eql(u8, name, "it")) return .it;
    if (std.mem.eql(u8, name, "fit")) return .fit;
    if (std.mem.eql(u8, name, "xit")) return .xit;
    if (std.mem.eql(u8, name, "expect")) return .expect;
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
    return switch (tree.data(unwrapTransparent(tree, index))) {
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

fn memberAccessorStart(tree: *const ast.Tree, member: ast.MemberExpression) ?usize {
    const source = tree.source;
    const object_end = tree.span(member.object).end;
    const property_start = tree.span(member.property).start;
    if (object_end > property_start or property_start > source.len) return null;

    var cursor = object_end;
    while (cursor < property_start) {
        if (std.ascii.isWhitespace(source[cursor])) {
            cursor += 1;
            continue;
        }
        if (cursor + 1 < property_start and source[cursor] == '/' and source[cursor + 1] == '/') {
            cursor += 2;
            while (cursor < property_start and source[cursor] != '\n' and source[cursor] != '\r') cursor += 1;
            continue;
        }
        if (cursor + 1 < property_start and source[cursor] == '/' and source[cursor + 1] == '*') {
            cursor += 2;
            while (cursor + 1 < property_start and !(source[cursor] == '*' and source[cursor + 1] == '/')) {
                cursor += 1;
            }
            if (cursor + 1 < property_start) cursor += 2;
            continue;
        }
        if (member.optional and source[cursor] == '?') return cursor;
        if (member.computed and source[cursor] == '[') return cursor;
        if (!member.computed and source[cursor] == '.') return cursor;
        cursor += 1;
    }
    return null;
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
