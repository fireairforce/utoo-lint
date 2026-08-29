const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "class-methods-use-this";

pub const Options = struct {
    enforce_for_class_fields: bool = true,
    except_methods: *const core.ClassMethodsUseThisExceptMethods,
    ignore_override_methods: bool = false,
    ignore_classes_with_implements: core.ClassMethodsUseThisIgnoreClassesWithImplements = .none,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    options: Options,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .options = options,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const ContextStack = struct {
    const capacity = 256;

    values: [capacity]bool = undefined,
    len: usize = 0,

    fn push(self: *ContextStack) void {
        if (self.len < capacity) self.values[self.len] = false;
        self.len += 1;
    }

    fn pop(self: *ContextStack) ?bool {
        if (self.len == 0) return null;
        self.len -= 1;
        // Suppress diagnostics when pathological nesting exceeded storage.
        if (self.len >= capacity) return true;
        return self.values[self.len];
    }

    fn markUsed(self: *ContextStack) void {
        if (self.len == 0 or self.len > capacity) return;
        self.values[self.len - 1] = true;
    }
};

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    options: Options,
    contexts: ContextStack = .{},

    pub fn enter_function(
        self: *Visitor,
        _: ast.Function,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        self.contexts.push();
        return .proceed;
    }

    pub fn exit_function(
        self: *Visitor,
        function: ast.Function,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        const uses_this = self.contexts.pop() orelse return;
        if (uses_this) return;

        const parent = directClassMemberParent(ctx.tree, ctx) orelse return;
        switch (parent) {
            .method_definition => |method| {
                if (!self.includesMethod(ctx.tree, method, ctx)) return;
                self.reportMethod(ctx.tree, method, function.async, function.generator) catch {};
            },
            .property_definition => |property| {
                if (!self.includesProperty(ctx.tree, property, ctx)) return;
                self.reportProperty(ctx.tree, property, function.async, function.generator) catch {};
            },
        }
    }

    pub fn enter_arrow_function_expression(
        self: *Visitor,
        _: ast.ArrowFunctionExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) traverser.Action {
        if (directPropertyParent(ctx.tree, ctx) != null) self.contexts.push();
        return .proceed;
    }

    pub fn exit_arrow_function_expression(
        self: *Visitor,
        function: ast.ArrowFunctionExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        const property = directPropertyParent(ctx.tree, ctx) orelse return;
        const uses_this = self.contexts.pop() orelse return;
        if (uses_this or !self.includesProperty(ctx.tree, property, ctx)) return;
        self.reportProperty(ctx.tree, property, function.async, false) catch {};
    }

    pub fn enter_static_block(
        self: *Visitor,
        _: ast.StaticBlock,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        self.contexts.push();
        return .proceed;
    }

    pub fn exit_static_block(
        self: *Visitor,
        _: ast.StaticBlock,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        _ = self.contexts.pop();
    }

    pub fn enter_this_expression(
        self: *Visitor,
        _: ast.ThisExpression,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        self.contexts.markUsed();
        return .proceed;
    }

    pub fn enter_super(
        self: *Visitor,
        _: ast.Super,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        self.contexts.markUsed();
        return .proceed;
    }

    pub fn exit_property_definition(
        self: *Visitor,
        _: ast.PropertyDefinition,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        _ = self.contexts.pop();
    }

    pub fn exit_node(
        self: *Visitor,
        _: ast.NodeData,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        const parent_index = ctx.path.parent() orelse return;
        const property = switch (ctx.tree.data(parent_index)) {
            .property_definition => |property| property,
            else => return,
        };
        if (property.key == index) self.contexts.push();
    }

    fn includesMethod(
        self: *const Visitor,
        tree: *const ast.Tree,
        method: ast.MethodDefinition,
        ctx: *traverser.basic.Ctx,
    ) bool {
        if (method.static or method.kind == .constructor) return false;
        return self.includesMember(tree, method.key, method.computed, method.override, method.accessibility, ctx);
    }

    fn includesProperty(
        self: *const Visitor,
        tree: *const ast.Tree,
        property: ast.PropertyDefinition,
        ctx: *traverser.basic.Ctx,
    ) bool {
        if (property.static or !self.options.enforce_for_class_fields) return false;
        return self.includesMember(tree, property.key, property.computed, property.override, property.accessibility, ctx);
    }

    fn includesMember(
        self: *const Visitor,
        tree: *const ast.Tree,
        key: ast.NodeIndex,
        computed: bool,
        override: bool,
        accessibility: ast.Accessibility,
        ctx: *traverser.basic.Ctx,
    ) bool {
        // ESLint intentionally applies configured exceptions only to non-computed members.
        if (computed) return true;
        if (self.options.ignore_override_methods and override) return false;

        if (self.options.ignore_classes_with_implements != .none) {
            if (nearestClass(tree, ctx)) |class| {
                if (class.type == .class_declaration and class.implements.len > 0) {
                    if (self.options.ignore_classes_with_implements == .all) return false;
                    if (!isPrivateKey(tree, key) and (accessibility == .none or accessibility == .public)) return false;
                }
            }
        }

        return !exceptMethodsContains(self.options.except_methods, tree, key);
    }

    fn reportMethod(
        self: *Visitor,
        tree: *const ast.Tree,
        method: ast.MethodDefinition,
        async_function: bool,
        generator: bool,
    ) Allocator.Error!void {
        const kind = switch (method.kind) {
            .get => "getter",
            .set => "setter",
            else => "method",
        };
        try self.report(tree, method.key, method.computed, kind, async_function, generator);
    }

    fn reportProperty(
        self: *Visitor,
        tree: *const ast.Tree,
        property: ast.PropertyDefinition,
        async_function: bool,
        generator: bool,
    ) Allocator.Error!void {
        try self.report(tree, property.key, property.computed, "method", async_function, generator);
    }

    fn report(
        self: *Visitor,
        tree: *const ast.Tree,
        key: ast.NodeIndex,
        computed: bool,
        kind: []const u8,
        async_function: bool,
        generator: bool,
    ) Allocator.Error!void {
        const name = staticMemberName(tree, key, computed);
        const private_prefix = if (name != null and name.?.private) "private " else "";
        const async_prefix = if (async_function) "async " else "";
        const generator_prefix = if (generator) "generator " else "";
        const span = tree.span(key);

        if (name) |member_name| {
            if (member_name.private) {
                try core.addDiagnosticFmt(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    span,
                    "Expected 'this' to be used by class {s}{s}{s}{s} #{s}.",
                    .{ private_prefix, async_prefix, generator_prefix, kind, member_name.value },
                );
            } else {
                try core.addDiagnosticFmt(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    span,
                    "Expected 'this' to be used by class {s}{s}{s}{s} '{s}'.",
                    .{ private_prefix, async_prefix, generator_prefix, kind, member_name.value },
                );
            }
            return;
        }

        try core.addDiagnosticFmt(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            span,
            "Expected 'this' to be used by class {s}{s}{s}{s}.",
            .{ private_prefix, async_prefix, generator_prefix, kind },
        );
    }
};

const ClassMemberParent = union(enum) {
    method_definition: ast.MethodDefinition,
    property_definition: ast.PropertyDefinition,
};

fn directPropertyParent(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) ?ast.PropertyDefinition {
    return switch (directClassMemberParent(tree, ctx) orelse return null) {
        .property_definition => |property| property,
        .method_definition => null,
    };
}

fn directClassMemberParent(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) ?ClassMemberParent {
    var child = ctx.path.ancestor(0) orelse return null;
    var depth: usize = 1;

    while (ctx.path.ancestor(depth)) |parent_index| : (depth += 1) {
        switch (tree.data(parent_index)) {
            .parenthesized_expression => |parenthesized| {
                if (parenthesized.expression != child) return null;
                child = parent_index;
            },
            .method_definition => |method| return if (method.value == child)
                .{ .method_definition = method }
            else
                null,
            .property_definition => |property| return if (property.value == child)
                .{ .property_definition = property }
            else
                null,
            else => return null,
        }
    }
    return null;
}

fn nearestClass(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) ?ast.Class {
    var ancestors = ctx.path.ancestors();
    _ = ancestors.next();
    while (ancestors.next()) |index| {
        switch (tree.data(index)) {
            .class => |class| return class,
            else => {},
        }
    }
    return null;
}

fn isPrivateKey(tree: *const ast.Tree, key: ast.NodeIndex) bool {
    return tree.data(key) == .private_identifier;
}

fn exceptMethodsContains(
    except_methods: *const core.ClassMethodsUseThisExceptMethods,
    tree: *const ast.Tree,
    key: ast.NodeIndex,
) bool {
    const name = staticMemberName(tree, key, false) orelse return false;
    if (!name.private) return except_methods.contains(name.value);

    for (0..except_methods.count) |index| {
        const exception = except_methods.at(index);
        if (exception.len == name.value.len + 1 and exception[0] == '#' and
            std.mem.eql(u8, exception[1..], name.value)) return true;
    }
    return false;
}

const StaticMemberName = struct {
    value: []const u8,
    private: bool = false,
};

fn staticMemberName(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) ?StaticMemberName {
    return switch (tree.data(key)) {
        .identifier_name => |identifier| if (computed) null else .{ .value = tree.string(identifier.name) },
        .private_identifier => |identifier| if (computed) null else .{ .value = tree.string(identifier.name), .private = true },
        .string_literal => |literal| .{ .value = tree.string(literal.value) },
        .numeric_literal => |literal| .{ .value = tree.string(literal.raw) },
        .template_literal => |template| staticTemplateName(tree, template),
        else => null,
    };
}

fn staticTemplateName(tree: *const ast.Tree, template: ast.TemplateLiteral) ?StaticMemberName {
    if (template.expressions.len != 0) return null;
    const quasis = tree.extra(template.quasis);
    if (quasis.len != 1) return null;
    return switch (tree.data(quasis[0])) {
        .template_element => |element| .{ .value = tree.string(element.cooked) },
        else => null,
    };
}
