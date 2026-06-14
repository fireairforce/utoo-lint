const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-undefined";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,

    pub fn enter_identifier_reference(
        self: *Visitor,
        identifier: ast.IdentifierReference,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkName(ctx.tree, identifier.name, index);
        return .proceed;
    }

    pub fn enter_variable_declarator(
        self: *Visitor,
        declarator: ast.VariableDeclarator,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkBinding(ctx.tree, declarator.id);
        return .proceed;
    }

    pub fn enter_function(
        self: *Visitor,
        function: ast.Function,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkBinding(ctx.tree, function.id);
        try self.checkFormalParameters(ctx.tree, function.params);
        return .proceed;
    }

    pub fn enter_arrow_function_expression(
        self: *Visitor,
        arrow: ast.ArrowFunctionExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkFormalParameters(ctx.tree, arrow.params);
        return .proceed;
    }

    pub fn enter_class(
        self: *Visitor,
        class: ast.Class,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkBinding(ctx.tree, class.id);
        return .proceed;
    }

    pub fn enter_catch_clause(
        self: *Visitor,
        clause: ast.CatchClause,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkBinding(ctx.tree, clause.param);
        return .proceed;
    }

    fn checkFormalParameters(
        self: *Visitor,
        tree: *const ast.Tree,
        params_index: ast.NodeIndex,
    ) Allocator.Error!void {
        if (params_index == .null) return;

        const params = switch (tree.data(params_index)) {
            .formal_parameters => |params| params,
            else => return,
        };

        for (tree.extra(params.items)) |item_index| {
            switch (tree.data(item_index)) {
                .formal_parameter => |parameter| try self.checkBinding(tree, parameter.pattern),
                .ts_parameter_property => |property| try self.checkBinding(tree, property.parameter),
                else => {},
            }
        }

        try self.checkBinding(tree, params.rest);
    }

    fn checkBinding(
        self: *Visitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
    ) Allocator.Error!void {
        if (index == .null) return;

        switch (tree.data(index)) {
            .binding_identifier => |identifier| try self.checkName(tree, identifier.name, index),
            .assignment_pattern => |pattern| try self.checkBinding(tree, pattern.left),
            .binding_rest_element => |element| try self.checkBinding(tree, element.argument),
            .array_pattern => |pattern| {
                for (tree.extra(pattern.elements)) |element| {
                    try self.checkBinding(tree, element);
                }
                try self.checkBinding(tree, pattern.rest);
            },
            .object_pattern => |pattern| {
                for (tree.extra(pattern.properties)) |property_index| {
                    const property = switch (tree.data(property_index)) {
                        .binding_property => |property| property,
                        else => continue,
                    };
                    try self.checkBinding(tree, property.value);
                }
                try self.checkBinding(tree, pattern.rest);
            },
            else => {},
        }
    }

    fn checkName(
        self: *Visitor,
        tree: *const ast.Tree,
        name_string: ast.String,
        index: ast.NodeIndex,
    ) Allocator.Error!void {
        const name = tree.string(name_string);
        if (!std.mem.eql(u8, name, "undefined")) return;

        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "Unexpected use of undefined.",
            tree.span(index),
        );
    }
};
