const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/prefer-click-with-debounce";

const message = "异步点击事件(async function)必须防抖处理.";
const SymbolId = traverser.semantic.SymbolId;
const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, SymbolId);
const DeclSymbolMap = std.AutoHashMap(ast.NodeIndex, SymbolId);
const DefinitionMap = std.AutoHashMap(ast.NodeIndex, ast.NodeIndex);

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var reference_lookup = ReferenceLookup.init(allocator);
    defer reference_lookup.deinit();

    var decl_symbols = DeclSymbolMap.init(allocator);
    defer decl_symbols.deinit();

    var symbol_iter = symbol_table.iterSymbols();
    while (symbol_iter.next()) |entry| {
        for (symbol_table.symbolDecls(entry.id)) |decl| {
            try decl_symbols.put(decl, entry.id);
        }
    }

    var reference_iter = symbol_table.iterReferences();
    while (reference_iter.next()) |entry| {
        if (entry.reference.kind != .value) continue;
        try reference_lookup.put(entry.reference.node, symbol_table.referenceSymbol(entry.id));
    }

    var definitions = DefinitionMap.init(allocator);
    defer definitions.deinit();

    var definition_visitor = DefinitionVisitor{
        .definitions = &definitions,
    };
    try traverser.basic.traverse(DefinitionVisitor, tree, &definition_visitor);

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .reference_lookup = &reference_lookup,
        .decl_symbols = &decl_symbols,
        .definitions = &definitions,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const DefinitionVisitor = struct {
    definitions: *DefinitionMap,

    pub fn enter_variable_declarator(
        self: *DefinitionVisitor,
        declarator: ast.VariableDeclarator,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (bindingIdentifierName(ctx.tree, declarator.id) != null) {
            try self.definitions.put(declarator.id, index);
        }
        return .proceed;
    }

    pub fn enter_function(
        self: *DefinitionVisitor,
        function: ast.Function,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (function.type != .function_declaration) return .proceed;
        if (bindingIdentifierName(ctx.tree, function.id) != null) {
            try self.definitions.put(function.id, index);
        }
        return .proceed;
    }
};

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    reference_lookup: *const ReferenceLookup,
    decl_symbols: *const DeclSymbolMap,
    definitions: *const DefinitionMap,

    pub fn enter_jsx_element(
        self: *Visitor,
        element: ast.JSXElement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const on_click = onClickAttribute(ctx.tree, element) orelse return .proceed;
        const click_handler = jsxExpression(ctx.tree, on_click.attribute.value) orelse return .proceed;

        switch (ctx.tree.data(click_handler)) {
            .identifier_reference => {
                const definition = self.definitionForReference(click_handler) orelse return .proceed;
                _ = try self.validateDefinition(ctx.tree, definition, click_handler);
            },
            .arrow_function_expression => |arrow| {
                if (arrow.async) {
                    try self.report(ctx.tree, on_click.index);
                }
            },
            else => {},
        }
        return .proceed;
    }

    pub fn enter_variable_declarator(
        self: *Visitor,
        declarator: ast.VariableDeclarator,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const name = bindingIdentifierName(ctx.tree, declarator.id) orelse return .proceed;
        if (std.mem.startsWith(u8, name, "DDD")) {
            _ = try self.validateDefinition(ctx.tree, index, .null);
        }
        return .proceed;
    }

    pub fn enter_function(
        self: *Visitor,
        function: ast.Function,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (function.type != .function_declaration) return .proceed;
        const name = bindingIdentifierName(ctx.tree, function.id) orelse return .proceed;
        if (std.mem.startsWith(u8, name, "DDD")) {
            _ = try self.validateDefinition(ctx.tree, index, .null);
        }
        return .proceed;
    }

    fn definitionForReference(self: *Visitor, reference: ast.NodeIndex) ?ast.NodeIndex {
        const symbol_id = self.reference_lookup.get(reference) orelse return null;
        if (symbol_id == .none) return null;

        var iter = self.decl_symbols.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* != symbol_id) continue;
            return self.definitions.get(entry.key_ptr.*);
        }
        return null;
    }

    fn validateDefinition(
        self: *Visitor,
        tree: *const ast.Tree,
        definition: ast.NodeIndex,
        also_report_to: ast.NodeIndex,
    ) Allocator.Error!bool {
        return switch (tree.data(definition)) {
            .variable_declarator => |declarator| try self.validateVariableDeclarator(tree, declarator, also_report_to),
            .function => |function| try self.validateFunction(tree, function, definition, also_report_to),
            else => false,
        };
    }

    fn validateVariableDeclarator(
        self: *Visitor,
        tree: *const ast.Tree,
        declarator: ast.VariableDeclarator,
        also_report_to: ast.NodeIndex,
    ) Allocator.Error!bool {
        if (declarator.init == .null) return false;

        const init = unwrapTransparent(tree, declarator.init);
        if (callExpression(tree, init)) |call| {
            if (isDebouncedCall(tree, init, call)) return true;
            if (isUseCallbackLikeCall(tree, call) and firstArgumentIsAsyncFunction(tree, call)) {
                try self.report(tree, init);
                try self.reportOptional(tree, also_report_to);
                return true;
            }
        }

        if (bindingIdentifierName(tree, declarator.id) != null and isAsyncFunctionExpression(tree, init)) {
            try self.report(tree, declarator.id);
            try self.reportOptional(tree, also_report_to);
            return true;
        }

        return false;
    }

    fn validateFunction(
        self: *Visitor,
        tree: *const ast.Tree,
        function: ast.Function,
        definition: ast.NodeIndex,
        also_report_to: ast.NodeIndex,
    ) Allocator.Error!bool {
        _ = definition;
        if (function.type != .function_declaration or function.id == .null or !function.async) return false;
        try self.report(tree, function.id);
        try self.reportOptional(tree, also_report_to);
        return true;
    }

    fn reportOptional(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        if (index != .null) try self.report(tree, index);
    }

    fn report(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .@"error",
            id,
            message,
            tree.span(index),
        );
    }
};

const AttributeWithIndex = struct {
    attribute: ast.JSXAttribute,
    index: ast.NodeIndex,
};

fn onClickAttribute(tree: *const ast.Tree, element: ast.JSXElement) ?AttributeWithIndex {
    const opening = switch (tree.data(element.opening_element)) {
        .jsx_opening_element => |opening| opening,
        else => return null,
    };

    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = jsxIdentifierName(tree, attribute.name) orelse continue;
        if (std.mem.eql(u8, name, "onClick")) {
            return .{ .attribute = attribute, .index = attribute_index };
        }
    }
    return null;
}

fn jsxExpression(tree: *const ast.Tree, value_index: ast.NodeIndex) ?ast.NodeIndex {
    if (value_index == .null) return null;
    return switch (tree.data(value_index)) {
        .jsx_expression_container => |container| if (container.expression == .null) null else container.expression,
        else => null,
    };
}

fn isDebouncedCall(tree: *const ast.Tree, index: ast.NodeIndex, call: ast.CallExpression) bool {
    const callee_name = identifierName(tree, unwrapTransparent(tree, call.callee)) orelse return false;
    if (isUseCallbackLikeName(callee_name)) {
        const first = firstArgument(tree, call) orelse return false;
        const nested = callExpression(tree, unwrapTransparent(tree, first)) orelse return false;
        return isDebouncedCall(tree, unwrapTransparent(tree, first), nested);
    }
    _ = index;
    return containsIgnoreCase(callee_name, "debounce") or containsIgnoreCase(callee_name, "useLockFn");
}

fn isUseCallbackLikeCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const callee_name = identifierName(tree, unwrapTransparent(tree, call.callee)) orelse return false;
    return isUseCallbackLikeName(callee_name);
}

fn isUseCallbackLikeName(name: []const u8) bool {
    return std.mem.indexOf(u8, name, "useCallback") != null or
        std.mem.indexOf(u8, name, "useMemoizedFn") != null;
}

fn firstArgumentIsAsyncFunction(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const first = firstArgument(tree, call) orelse return false;
    return isAsyncFunctionExpression(tree, unwrapTransparent(tree, first));
}

fn firstArgument(tree: *const ast.Tree, call: ast.CallExpression) ?ast.NodeIndex {
    const args = tree.extra(call.arguments);
    if (args.len == 0) return null;
    return args[0];
}

fn isAsyncFunctionExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .arrow_function_expression => |arrow| arrow.async,
        .function => |function| switch (function.type) {
            .function_expression => function.async,
            else => false,
        },
        else => false,
    };
}

fn callExpression(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.CallExpression {
    return switch (tree.data(index)) {
        .call_expression => |call| call,
        else => null,
    };
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn jsxIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
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

fn containsIgnoreCase(value: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > value.len) return false;

    var index: usize = 0;
    while (index + needle.len <= value.len) : (index += 1) {
        if (std.ascii.eqlIgnoreCase(value[index .. index + needle.len], needle)) return true;
    }
    return false;
}
