const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-children-prop";

const nest_children_message = "Do not pass children as props. Instead, nest children between the opening and closing tags.";
const pass_children_as_args_message = "Do not pass children as props. Instead, pass them as additional arguments to React.createElement.";
const nest_function_message = "Do not nest a function between the opening and closing tags. Instead, pass it as a prop.";
const pass_function_as_args_message = "Do not pass a function as an additional argument to React.createElement. Instead, pass it as a prop.";

pub const ReactBindings = struct {
    pragma: []const u8 = "React",
    has_bare_create_element: bool = false,
};

pub const Options = struct {
    allow_functions: bool = false,
};

pub fn bindingsFromProgram(tree: *const ast.Tree, program: ast.Program) ReactBindings {
    var bindings = ReactBindings{
        .pragma = pragmaFromComments(tree) orelse "React",
    };

    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .import_declaration => |declaration| scanImportDeclaration(tree, declaration, &bindings),
            .variable_declaration => |declaration| scanVariableDeclaration(tree, declaration, bindings.pragma, &bindings),
            else => {},
        }
    }

    return bindings;
}

pub fn checkJSXAttribute(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    attribute: ast.JSXAttribute,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const name = jsxAttributeName(tree, attribute.name) orelse return;
    if (!std.mem.eql(u8, name, "children")) return;
    if (options.allow_functions and jsxAttributeValueIsFunction(tree, attribute.value)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        nest_children_message,
        tree.span(index),
    );
}

pub fn checkJSXElement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    element: ast.JSXElement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!options.allow_functions) return;

    const children = tree.extra(element.children);
    if (children.len != 1) return;

    const container = switch (tree.data(children[0])) {
        .jsx_expression_container => |container| container,
        else => return,
    };
    if (!isFunctionExpression(tree, container.expression)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        nest_function_message,
        tree.span(index),
    );
}

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    bindings: ReactBindings,
    options: Options,
) Allocator.Error!void {
    if (!isCreateElementCall(tree, call, bindings)) return;

    const arguments = tree.extra(call.arguments);
    if (arguments.len <= 1) return;

    const props = switch (tree.data(arguments[1])) {
        .object_expression => |object| tree.extra(object.properties),
        else => return,
    };

    for (props) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        const key = objectPropertyKeyName(tree, property) orelse continue;
        if (!std.mem.eql(u8, key, "children")) continue;
        if (options.allow_functions and isFunctionExpression(tree, property.value)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            pass_children_as_args_message,
            tree.span(index),
        );
        return;
    }

    if (options.allow_functions and arguments.len == 3 and isFunctionExpression(tree, arguments[2])) {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            pass_function_as_args_message,
            tree.span(index),
        );
    }
}

pub fn checkVariableDeclarator(tree: *const ast.Tree, declarator: ast.VariableDeclarator, bindings: *ReactBindings) void {
    if (declarator.init == .null) return;
    if (isBareCreateElementDeclarator(tree, declarator, bindings.pragma)) {
        bindings.has_bare_create_element = true;
    }
}

fn scanImportDeclaration(tree: *const ast.Tree, declaration: ast.ImportDeclaration, bindings: *ReactBindings) void {
    if (declaration.import_kind == .type) return;

    const source = stringLiteralValue(tree, declaration.source) orelse return;
    if (!sourceEqualsLowercasePragma(source, bindings.pragma)) return;

    for (tree.extra(declaration.specifiers)) |specifier_index| {
        const specifier = switch (tree.data(specifier_index)) {
            .import_specifier => |specifier| specifier,
            else => continue,
        };
        if (specifier.import_kind == .type) continue;

        const imported = propertyName(tree, specifier.imported) orelse continue;
        const local = bindingIdentifierName(tree, specifier.local) orelse continue;
        if (std.mem.eql(u8, imported, "createElement") and std.mem.eql(u8, local, "createElement")) {
            bindings.has_bare_create_element = true;
        }
    }
}

fn scanVariableDeclaration(
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    pragma: []const u8,
    bindings: *ReactBindings,
) void {
    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |declarator| declarator,
            else => continue,
        };
        if (declarator.init == .null) continue;

        if (isBareCreateElementDeclarator(tree, declarator, pragma)) {
            bindings.has_bare_create_element = true;
        }
    }
}

fn isBareCreateElementDeclarator(tree: *const ast.Tree, declarator: ast.VariableDeclarator, pragma: []const u8) bool {
    if (bindingIdentifierName(tree, declarator.id)) |name| {
        if (!std.mem.eql(u8, name, "createElement")) return false;
        return isPragmaCreateElementMember(tree, declarator.init, pragma) or isRequireReactCreateElementMember(tree, declarator.init, pragma);
    }

    const pattern = switch (tree.data(declarator.id)) {
        .object_pattern => |pattern| pattern,
        else => return false,
    };
    if (!isPragmaIdentifier(tree, declarator.init, pragma) and !isRequireReactCall(tree, declarator.init, pragma)) return false;

    for (tree.extra(pattern.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .binding_property => |property| property,
            else => continue,
        };
        if (property.computed) continue;

        const key = propertyName(tree, property.key) orelse continue;
        if (!std.mem.eql(u8, key, "createElement")) continue;

        const value = unwrapAssignmentPattern(tree, property.value);
        const local = bindingIdentifierName(tree, value) orelse continue;
        if (std.mem.eql(u8, local, "createElement")) return true;
    }

    return false;
}

fn isCreateElementCall(tree: *const ast.Tree, call: ast.CallExpression, bindings: ReactBindings) bool {
    const callee = unwrapTransparent(tree, call.callee);

    if (calleeIdentifierName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createElement") and bindings.has_bare_create_element;
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;

    const property = propertyName(tree, member.property) orelse return false;
    return std.mem.eql(u8, property, "createElement") and isPragmaIdentifier(tree, member.object, bindings.pragma);
}

fn isPragmaCreateElementMember(tree: *const ast.Tree, index: ast.NodeIndex, pragma: []const u8) bool {
    const member = switch (tree.data(unwrapTransparent(tree, index))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;

    const property = propertyName(tree, member.property) orelse return false;
    return std.mem.eql(u8, property, "createElement") and isPragmaIdentifier(tree, member.object, pragma);
}

fn isRequireReactCreateElementMember(tree: *const ast.Tree, index: ast.NodeIndex, pragma: []const u8) bool {
    const member = switch (tree.data(unwrapTransparent(tree, index))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;

    const property = propertyName(tree, member.property) orelse return false;
    return std.mem.eql(u8, property, "createElement") and isRequireReactCall(tree, member.object, pragma);
}

fn isRequireReactCall(tree: *const ast.Tree, index: ast.NodeIndex, pragma: []const u8) bool {
    const call = switch (tree.data(unwrapTransparent(tree, index))) {
        .call_expression => |call| call,
        else => return false,
    };
    const callee = calleeIdentifierName(tree, unwrapTransparent(tree, call.callee)) orelse return false;
    if (!std.mem.eql(u8, callee, "require")) return false;

    const arguments = tree.extra(call.arguments);
    if (arguments.len != 1) return false;
    const source = stringLiteralValue(tree, arguments[0]) orelse return false;
    return sourceEqualsLowercasePragma(source, pragma);
}

fn isPragmaIdentifier(tree: *const ast.Tree, index: ast.NodeIndex, pragma: []const u8) bool {
    const name = calleeIdentifierName(tree, unwrapTransparent(tree, index)) orelse return false;
    return std.mem.eql(u8, name, pragma);
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

fn isFunctionExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .arrow_function_expression => true,
        .function => |function| function.type == .function_expression or function.type == .ts_empty_body_function_expression,
        else => false,
    };
}

fn jsxAttributeValueIsFunction(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    const container = switch (tree.data(index)) {
        .jsx_expression_container => |container| container,
        else => return false,
    };
    return isFunctionExpression(tree, container.expression);
}

fn objectPropertyKeyName(tree: *const ast.Tree, property: ast.ObjectProperty) ?[]const u8 {
    if (property.computed) return null;
    return switch (tree.data(property.key)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
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

fn calleeIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn jsxAttributeName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn unwrapAssignmentPattern(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    return switch (tree.data(index)) {
        .assignment_pattern => |pattern| pattern.left,
        else => index,
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

fn isIdentifier(value: []const u8) bool {
    if (value.len == 0) return false;
    if (!isIdentifierStart(value[0])) return false;
    for (value[1..]) |byte| {
        if (!isIdentifierPart(byte)) return false;
    }
    return true;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_' or byte == '$';
}

fn isIdentifierPart(byte: u8) bool {
    return isIdentifierStart(byte) or std.ascii.isDigit(byte);
}

fn isWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\r' or byte == '\n';
}
