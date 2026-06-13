const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/button-has-type";

const missing_type_message = "Missing an explicit type attribute for button";
const complex_type_message = "The button type attribute must be specified by a static string or a trivial ternary expression";

pub const State = struct {
    pragma: []const u8 = "React",
    has_bare_create_element: bool = false,
};

pub fn collectProgram(tree: *const ast.Tree, program: ast.Program, state: *State) void {
    state.pragma = pragmaFromComments(tree) orelse "React";
    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        const source = stringLiteralValue(tree, declaration.source) orelse continue;
        if (!sourceEqualsLowercasePragma(source, state.pragma)) continue;
        for (tree.extra(declaration.specifiers)) |specifier_index| {
            const specifier = switch (tree.data(specifier_index)) {
                .import_specifier => |specifier| specifier,
                else => continue,
            };
            if (specifier.import_kind == .type) continue;
            const imported = propertyName(tree, specifier.imported) orelse continue;
            const local = bindingIdentifierName(tree, specifier.local) orelse continue;
            if (std.mem.eql(u8, imported, "createElement") and std.mem.eql(u8, local, "createElement")) {
                state.has_bare_create_element = true;
            }
        }
    }
}

pub fn checkJSXElement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    element: ast.JSXElement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const opening = switch (tree.data(element.opening_element)) {
        .jsx_opening_element => |opening| opening,
        else => return,
    };
    const name = jsxIdentifierName(tree, opening.name) orelse return;
    if (!std.mem.eql(u8, name, "button")) return;

    const type_attribute = findTypeAttribute(tree, opening) orelse {
        try report(allocator, diagnostics, tree, index, missing_type_message);
        return;
    };
    try checkJSXAttributeValue(allocator, diagnostics, tree, type_attribute);
}

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    state: State,
) Allocator.Error!void {
    if (!isCreateElementCall(tree, call, state)) return;

    const arguments = tree.extra(call.arguments);
    if (arguments.len < 1) return;
    if (!isStringLiteral(tree, arguments[0], "button")) return;

    if (arguments.len < 2) {
        try report(allocator, diagnostics, tree, index, missing_type_message);
        return;
    }

    const props = switch (tree.data(unwrapTransparent(tree, arguments[1]))) {
        .object_expression => |object| object,
        else => {
            try report(allocator, diagnostics, tree, index, missing_type_message);
            return;
        },
    };

    for (tree.extra(props.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        const key = objectPropertyKeyName(tree, property) orelse continue;
        if (!std.mem.eql(u8, key, "type")) continue;
        try checkExpressionValue(allocator, diagnostics, tree, property.value);
        return;
    }

    try report(allocator, diagnostics, tree, index, missing_type_message);
}

fn checkJSXAttributeValue(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    attribute: ast.JSXAttribute,
) Allocator.Error!void {
    if (attribute.value == .null) {
        try reportInvalidValue(allocator, diagnostics, tree, attribute.name, "true");
        return;
    }

    switch (tree.data(attribute.value)) {
        .string_literal => |literal| try checkValue(allocator, diagnostics, tree, attribute.value, tree.string(literal.value)),
        .jsx_expression_container => |container| try checkExpressionValue(allocator, diagnostics, tree, container.expression),
        else => try report(allocator, diagnostics, tree, attribute.value, complex_type_message),
    }
}

fn checkExpressionValue(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (index == .null) {
        try report(allocator, diagnostics, tree, index, complex_type_message);
        return;
    }

    const current = unwrapTransparent(tree, index);
    switch (tree.data(current)) {
        .string_literal => |literal| try checkValue(allocator, diagnostics, tree, current, tree.string(literal.value)),
        .template_literal => |literal| {
            if (literal.expressions.len != 0) {
                try report(allocator, diagnostics, tree, current, complex_type_message);
                return;
            }
            const quasis = tree.extra(literal.quasis);
            if (quasis.len == 0) {
                try reportInvalidValue(allocator, diagnostics, tree, current, "");
                return;
            }
            const element = switch (tree.data(quasis[0])) {
                .template_element => |element| element,
                else => return,
            };
            try checkValue(allocator, diagnostics, tree, current, tree.string(element.cooked));
        },
        .conditional_expression => |conditional| {
            try checkExpressionValue(allocator, diagnostics, tree, conditional.consequent);
            try checkExpressionValue(allocator, diagnostics, tree, conditional.alternate);
        },
        else => try report(allocator, diagnostics, tree, current, complex_type_message),
    }
}

fn checkValue(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    value: []const u8,
) Allocator.Error!void {
    if (isAllowedButtonType(value)) return;
    try reportInvalidValue(allocator, diagnostics, tree, index, value);
}

fn isAllowedButtonType(value: []const u8) bool {
    return std.mem.eql(u8, value, "button") or
        std.mem.eql(u8, value, "submit") or
        std.mem.eql(u8, value, "reset");
}

fn findTypeAttribute(tree: *const ast.Tree, opening: ast.JSXOpeningElement) ?ast.JSXAttribute {
    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = jsxIdentifierName(tree, attribute.name) orelse continue;
        if (std.mem.eql(u8, name, "type")) return attribute;
    }
    return null;
}

fn isCreateElementCall(tree: *const ast.Tree, call: ast.CallExpression, state: State) bool {
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createElement") and state.has_bare_create_element;
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member.property) orelse return false;
    if (!std.mem.eql(u8, property, "createElement")) return false;
    return isIdentifierReference(tree, member.object, state.pragma);
}

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    message: []const u8,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        message,
        tree.span(index),
    );
}

fn reportInvalidValue(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    value: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "\"{s}\" is an invalid value for button type attribute",
        .{value},
    );
}

fn objectPropertyKeyName(tree: *const ast.Tree, property: ast.ObjectProperty) ?[]const u8 {
    if (property.computed) return null;
    return propertyName(tree, property.key);
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn jsxIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
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

fn isStringLiteral(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    const value = stringLiteralValue(tree, unwrapTransparent(tree, index)) orelse return false;
    return std.mem.eql(u8, value, expected);
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
