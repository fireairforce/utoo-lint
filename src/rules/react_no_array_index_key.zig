const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-array-index-key";

const iterator_functions = [_]struct { name: []const u8, index_param_position: usize }{
    .{ .name = "every", .index_param_position = 1 },
    .{ .name = "filter", .index_param_position = 1 },
    .{ .name = "find", .index_param_position = 1 },
    .{ .name = "findIndex", .index_param_position = 1 },
    .{ .name = "flatMap", .index_param_position = 1 },
    .{ .name = "forEach", .index_param_position = 1 },
    .{ .name = "map", .index_param_position = 1 },
    .{ .name = "reduce", .index_param_position = 2 },
    .{ .name = "reduceRight", .index_param_position = 2 },
    .{ .name = "some", .index_param_position = 1 },
};

pub const State = struct {
    index_param_names: std.ArrayList([]const u8) = .empty,
    create_clone_names: std.ArrayList([]const u8) = .empty,
    pragma: []const u8 = "React",

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.index_param_names.deinit(allocator);
        self.create_clone_names.deinit(allocator);
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
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        const source = stringLiteralValue(tree, declaration.source) orelse continue;
        if (!std.mem.eql(u8, source, "react")) continue;

        for (tree.extra(declaration.specifiers)) |specifier_index| {
            const specifier = switch (tree.data(specifier_index)) {
                .import_specifier => |specifier| specifier,
                else => continue,
            };
            const imported = staticName(tree, specifier.imported) orelse continue;
            if (!std.mem.eql(u8, imported, "createElement") and !std.mem.eql(u8, imported, "cloneElement")) continue;
            const local = bindingIdentifierName(tree, specifier.local) orelse continue;
            try state.create_clone_names.append(allocator, local);
        }
    }
}

pub fn enterCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    if (isCreateCloneElementCall(tree, call, state.*)) {
        if (state.index_param_names.items.len == 0) return;
        try checkCreateElementProps(allocator, diagnostics, tree, call, index, state.*);
        return;
    }

    const index_param_name = mapIndexParamName(tree, call, state.*) orelse return;
    try state.index_param_names.append(allocator, index_param_name);
}

pub fn exitCallExpression(tree: *const ast.Tree, call: ast.CallExpression, state: *State) void {
    if (mapIndexParamName(tree, call, state.*) == null) return;
    _ = state.index_param_names.pop();
}

pub fn checkJSXAttribute(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    attribute: ast.JSXAttribute,
    state: State,
) Allocator.Error!void {
    if (state.index_param_names.items.len == 0) return;
    const name = jsxIdentifierName(tree, attribute.name) orelse return;
    if (!std.mem.eql(u8, name, "key")) return;

    const container = switch (tree.data(attribute.value)) {
        .jsx_expression_container => |container| container,
        else => return,
    };
    try checkPropValue(allocator, diagnostics, tree, container.expression, state);
}

fn checkCreateElementProps(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    state: State,
) Allocator.Error!void {
    _ = index;
    const arguments = tree.extra(call.arguments);
    if (arguments.len <= 1) return;

    const props = switch (tree.data(unwrapTransparent(tree, arguments[1]))) {
        .object_expression => |object| object,
        else => return,
    };

    for (tree.extra(props.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        const key = objectPropertyKeyName(tree, property) orelse continue;
        if (!std.mem.eql(u8, key, "key")) continue;
        try checkPropValue(allocator, diagnostics, tree, property.value, state);
    }
}

fn checkPropValue(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    state: State,
) Allocator.Error!void {
    const current = unwrapTransparent(tree, index);
    switch (tree.data(current)) {
        .identifier_reference => |identifier| {
            if (isArrayIndexName(tree.string(identifier.name), state)) {
                try report(allocator, diagnostics, tree, current);
            }
        },
        .template_literal => |literal| {
            for (tree.extra(literal.expressions)) |expression| {
                if (isArrayIndexReference(tree, expression, state)) {
                    try report(allocator, diagnostics, tree, current);
                }
            }
        },
        .binary_expression => {
            const count = countArrayIndexReferences(tree, current, state);
            var i: usize = 0;
            while (i < count) : (i += 1) {
                try report(allocator, diagnostics, tree, current);
            }
        },
        .call_expression => |call| {
            if (isIndexToStringCall(tree, call, state)) {
                try report(allocator, diagnostics, tree, current);
                return;
            }
            if (isStringIndexCall(tree, call, state)) |argument| {
                try report(allocator, diagnostics, tree, argument);
            }
        },
        else => {},
    }
}

fn mapIndexParamName(tree: *const ast.Tree, call: ast.CallExpression, state: State) ?[]const u8 {
    const callee = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return null,
    };
    const method = propertyName(tree, callee) orelse return null;
    const position = iteratorIndexParamPosition(method) orelse return null;

    const arguments = tree.extra(call.arguments);
    const callback_index: usize = if (isReactChildrenIterator(tree, callee, state)) 1 else 0;
    if (arguments.len <= callback_index) return null;

    const callback = unwrapTransparent(tree, arguments[callback_index]);
    const params_index = switch (tree.data(callback)) {
        .arrow_function_expression => |function| function.params,
        .function => |function| switch (function.type) {
            .function_expression => function.params,
            else => return null,
        },
        else => return null,
    };

    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return null,
    };
    const items = tree.extra(params.items);
    if (items.len <= position) return null;

    const parameter = switch (tree.data(items[position])) {
        .formal_parameter => |parameter| parameter,
        else => return null,
    };
    return bindingIdentifierName(tree, parameter.pattern);
}

fn iteratorIndexParamPosition(method: []const u8) ?usize {
    for (iterator_functions) |entry| {
        if (std.mem.eql(u8, method, entry.name)) return entry.index_param_position;
    }
    return null;
}

fn isReactChildrenIterator(tree: *const ast.Tree, callee: ast.MemberExpression, state: State) bool {
    const method = propertyName(tree, callee) orelse return false;
    if (!std.mem.eql(u8, method, "map") and !std.mem.eql(u8, method, "forEach")) return false;

    const object = unwrapTransparent(tree, callee.object);
    if (identifierReferenceName(tree, object)) |name| {
        return std.mem.eql(u8, name, "Children");
    }
    const member = switch (tree.data(object)) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member) orelse return false;
    const root = identifierReferenceName(tree, unwrapTransparent(tree, member.object)) orelse return false;
    return std.mem.eql(u8, property, "Children") and std.mem.eql(u8, root, state.pragma);
}

fn isCreateCloneElementCall(tree: *const ast.Tree, call: ast.CallExpression, state: State) bool {
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierReferenceName(tree, callee)) |name| {
        for (state.create_clone_names.items) |local| {
            if (std.mem.eql(u8, name, local)) return true;
        }
        return false;
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member) orelse return false;
    if (!std.mem.eql(u8, property, "createElement") and !std.mem.eql(u8, property, "cloneElement")) return false;
    const object = identifierReferenceName(tree, unwrapTransparent(tree, member.object)) orelse return false;
    return std.mem.eql(u8, object, state.pragma);
}

fn isArrayIndexReference(tree: *const ast.Tree, index: ast.NodeIndex, state: State) bool {
    const name = identifierReferenceName(tree, unwrapTransparent(tree, index)) orelse return false;
    return isArrayIndexName(name, state);
}

fn isArrayIndexName(name: []const u8, state: State) bool {
    for (state.index_param_names.items) |index_name| {
        if (std.mem.eql(u8, name, index_name)) return true;
    }
    return false;
}

fn countArrayIndexReferences(tree: *const ast.Tree, index: ast.NodeIndex, state: State) usize {
    const current = unwrapTransparent(tree, index);
    if (isArrayIndexReference(tree, current, state)) return 1;
    const binary = switch (tree.data(current)) {
        .binary_expression => |binary| binary,
        else => return 0,
    };
    return countArrayIndexReferences(tree, binary.left, state) +
        countArrayIndexReferences(tree, binary.right, state);
}

fn isIndexToStringCall(tree: *const ast.Tree, call: ast.CallExpression, state: State) bool {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member) orelse return false;
    return std.mem.eql(u8, property, "toString") and isArrayIndexReference(tree, member.object, state);
}

fn isStringIndexCall(tree: *const ast.Tree, call: ast.CallExpression, state: State) ?ast.NodeIndex {
    const callee = identifierReferenceName(tree, unwrapTransparent(tree, call.callee)) orelse return null;
    if (!std.mem.eql(u8, callee, "String")) return null;
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return null;
    return if (isArrayIndexReference(tree, arguments[0], state)) arguments[0] else null;
}

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Do not use Array index in keys",
        tree.span(index),
    );
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;
    if (member.computed) return null;
    return staticName(tree, member.property);
}

fn objectPropertyKeyName(tree: *const ast.Tree, property: ast.ObjectProperty) ?[]const u8 {
    if (property.computed) return null;
    return staticName(tree, property.key);
}

fn staticName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
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
