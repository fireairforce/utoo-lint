const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/require-render-return";

const message = "Your render method should have a return statement";

pub const State = struct {
    pragma: []const u8 = "React",
    component_names: std.ArrayList([]const u8) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.component_names.deinit(allocator);
    }
};

pub fn collectProgram(
    allocator: Allocator,
    tree: *const ast.Tree,
    program: ast.Program,
    state: *State,
) Allocator.Error!void {
    state.pragma = pragmaFromComments(tree) orelse "React";

    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .import_declaration => |declaration| try scanImportDeclaration(allocator, tree, declaration, state),
            else => {},
        }
    }
}

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
    state: State,
) Allocator.Error!void {
    if (!isReactComponentClass(tree, class, state)) return;

    const body = switch (tree.data(class.body)) {
        .class_body => |body| body,
        else => return,
    };

    for (tree.extra(body.body)) |member_index| {
        const render_value = switch (tree.data(member_index)) {
            .method_definition => |method| if (isRenderMethod(tree, method)) method.value else continue,
            .property_definition => |property| if (isRenderPropertyDefinition(tree, property)) property.value else continue,
            else => continue,
        };
        if (functionHasReturn(tree, render_value)) return;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            message,
            tree.span(member_index),
        );
        return;
    }
}

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    state: State,
) Allocator.Error!void {
    if (!isCreateClassCall(tree, call, state)) return;

    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return;

    const spec = switch (tree.data(unwrapTransparent(tree, arguments[0]))) {
        .object_expression => |object| object,
        else => return,
    };

    for (tree.extra(spec.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        if (!isRenderProperty(tree, property)) continue;
        if (functionHasReturn(tree, property.value)) return;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            message,
            tree.span(property_index),
        );
        return;
    }

    _ = index;
}

fn scanImportDeclaration(
    allocator: Allocator,
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    state: *State,
) Allocator.Error!void {
    if (declaration.import_kind == .type) return;
    const source = stringLiteralValue(tree, declaration.source) orelse return;
    if (!sourceEqualsLowercasePragma(source, state.pragma)) return;

    for (tree.extra(declaration.specifiers)) |specifier_index| {
        switch (tree.data(specifier_index)) {
            .import_specifier => |specifier| {
                if (specifier.import_kind == .type) continue;
                const imported = propertyName(tree, specifier.imported) orelse continue;
                if (!std.mem.eql(u8, imported, "Component") and !std.mem.eql(u8, imported, "PureComponent")) continue;
                const local = bindingIdentifierName(tree, specifier.local) orelse continue;
                try state.component_names.append(allocator, local);
            },
            else => {},
        }
    }
}

fn isReactComponentClass(tree: *const ast.Tree, class: ast.Class, state: State) bool {
    if (class.super_class == .null) return false;
    const super_class = unwrapTransparent(tree, class.super_class);
    if (identifierReferenceName(tree, super_class)) |name| {
        return isImportedComponentName(name, state);
    }

    const member = switch (tree.data(super_class)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (!isIdentifierReference(tree, member.object, state.pragma)) return false;
    const property = propertyName(tree, member.property) orelse return false;
    return std.mem.eql(u8, property, "Component") or std.mem.eql(u8, property, "PureComponent");
}

fn isImportedComponentName(name: []const u8, state: State) bool {
    for (state.component_names.items) |component_name| {
        if (std.mem.eql(u8, name, component_name)) return true;
    }
    return false;
}

fn isCreateClassCall(tree: *const ast.Tree, call: ast.CallExpression, state: State) bool {
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createReactClass");
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member.property) orelse return false;
    if (!std.mem.eql(u8, property, "createClass")) return false;
    return isIdentifierReference(tree, member.object, state.pragma);
}

fn isRenderMethod(tree: *const ast.Tree, method: ast.MethodDefinition) bool {
    if (method.static) return false;
    const name = propertyName(tree, method.key) orelse return false;
    return std.mem.eql(u8, name, "render");
}

fn isRenderProperty(tree: *const ast.Tree, property: ast.ObjectProperty) bool {
    if (property.computed) return false;
    const name = propertyName(tree, property.key) orelse return false;
    if (!std.mem.eql(u8, name, "render")) return false;
    return isFunctionLike(tree, property.value);
}

fn isRenderPropertyDefinition(tree: *const ast.Tree, property: ast.PropertyDefinition) bool {
    if (property.static or property.computed or property.value == .null) return false;
    const name = propertyName(tree, property.key) orelse return false;
    if (!std.mem.eql(u8, name, "render")) return false;
    return isFunctionLike(tree, property.value);
}

fn isFunctionLike(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .function, .arrow_function_expression => true,
        else => false,
    };
}

fn functionHasReturn(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const current = unwrapTransparent(tree, index);
    switch (tree.data(current)) {
        .arrow_function_expression => |function| {
            if (function.expression) return true;
            return functionBodyHasReturn(tree, function.body);
        },
        .function => |function| {
            if (function.body == .null) return false;
            return functionBodyHasReturn(tree, function.body);
        },
        else => return false,
    }
}

fn functionBodyHasReturn(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const body = switch (tree.data(index)) {
        .function_body => |body| body.body,
        .block_statement => |block| block.body,
        else => return false,
    };
    return statementsHaveReturn(tree, body);
}

fn statementsHaveReturn(tree: *const ast.Tree, range: ast.IndexRange) bool {
    for (tree.extra(range)) |statement_index| {
        if (statementHasReturn(tree, statement_index)) return true;
    }
    return false;
}

fn statementHasReturn(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    switch (tree.data(index)) {
        .return_statement => return true,
        .if_statement => |statement| {
            if (statementHasReturn(tree, statement.consequent)) return true;
            return statement.alternate != .null and statementHasReturn(tree, statement.alternate);
        },
        .block_statement => |block| return statementsHaveReturn(tree, block.body),
        .function, .arrow_function_expression => return false,
        else => return false,
    }
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierReference(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    const name = identifierReferenceName(tree, unwrapTransparent(tree, index)) orelse return false;
    return std.mem.eql(u8, name, expected);
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn pragmaFromComments(tree: *const ast.Tree) ?[]const u8 {
    for (tree.comments) |comment| {
        const value = tree.string(comment.value);
        const marker_index = std.mem.indexOf(u8, value, "@jsx") orelse continue;
        var cursor = marker_index + "@jsx".len;

        if (cursor >= value.len or !isWhitespace(value[cursor])) continue;
        while (cursor < value.len and isWhitespace(value[cursor])) : (cursor += 1) {}

        const start = cursor;
        while (cursor < value.len and !isWhitespace(value[cursor])) : (cursor += 1) {}
        var pragma = value[start..cursor];
        if (std.mem.indexOfScalar(u8, pragma, '.')) |dot_index| {
            pragma = pragma[0..dot_index];
        }
        if (isIdentifier(pragma)) return pragma;
    }
    return null;
}

fn sourceEqualsLowercasePragma(source: []const u8, pragma: []const u8) bool {
    if (source.len != pragma.len) return false;
    for (source, pragma) |source_byte, pragma_byte| {
        if (source_byte != std.ascii.toLower(pragma_byte)) return false;
    }
    return true;
}

fn isWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\n' or byte == '\r';
}

fn isIdentifier(value: []const u8) bool {
    if (value.len == 0) return false;
    if (!isIdentifierStart(value[0])) return false;
    for (value[1..]) |byte| {
        if (!isIdentifierContinue(byte)) return false;
    }
    return true;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_' or byte == '$';
}

fn isIdentifierContinue(byte: u8) bool {
    return isIdentifierStart(byte) or std.ascii.isDigit(byte);
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
