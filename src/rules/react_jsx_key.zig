const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/jsx-key";

const missing_array_key_message = "Missing \"key\" prop for element in array";
const missing_iter_key_message = "Missing \"key\" prop for element in iterator";
const non_unique_key_message = "`key` prop must be unique";

pub const State = struct {
    pragma: []const u8 = "React",
    children_to_array_depth: usize = 0,
};

pub const Options = struct {
    check_key_must_before_spread: bool = false,
    check_fragment_shorthand: bool = false,
    warn_on_duplicates: bool = false,
};

const KeyProp = struct {
    value: []const u8,
    node: ast.NodeIndex,
};

pub fn collectProgram(tree: *const ast.Tree, state: *State) void {
    state.pragma = pragmaFromComments(tree) orelse "React";
}

pub fn enterCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (isChildrenToArrayCall(tree, call, state.*)) {
        state.children_to_array_depth += 1;
        return;
    }
    if (state.children_to_array_depth > 0) return;

    const callback = iteratorCallback(tree, call) orelse return;
    try checkIteratorCallback(allocator, diagnostics, tree, callback, options);
}

pub fn exitCallExpression(tree: *const ast.Tree, call: ast.CallExpression, state: *State) void {
    if (!isChildrenToArrayCall(tree, call, state.*)) return;
    if (state.children_to_array_depth > 0) {
        state.children_to_array_depth -= 1;
    }
}

pub fn checkArrayExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrayExpression,
    options: Options,
) Allocator.Error!void {
    var keys: std.ArrayList(KeyProp) = .empty;
    defer keys.deinit(allocator);

    for (tree.extra(expression.elements)) |element_index| {
        if (element_index == .null) continue;
        const element = switch (tree.data(unwrapTransparent(tree, element_index))) {
            .jsx_element => |element| element,
            .jsx_fragment => {
                if (options.check_fragment_shorthand) {
                    try report(allocator, diagnostics, tree, element_index, missing_array_key_message);
                }
                continue;
            },
            else => continue,
        };
        if (options.warn_on_duplicates) {
            try collectKeyProps(allocator, tree, element, &keys);
        }
        if (hasKeyProp(tree, element, options)) continue;
        try report(allocator, diagnostics, tree, element_index, missing_array_key_message);
    }

    if (options.warn_on_duplicates) {
        try reportDuplicateKeys(allocator, diagnostics, tree, keys.items);
    }
}

pub fn checkJSXElementChildren(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    element: ast.JSXElement,
    options: Options,
) Allocator.Error!void {
    if (!options.warn_on_duplicates) return;

    var keys: std.ArrayList(KeyProp) = .empty;
    defer keys.deinit(allocator);

    for (tree.extra(element.children)) |child_index| {
        const child = switch (tree.data(unwrapTransparent(tree, child_index))) {
            .jsx_element => |child| child,
            else => continue,
        };
        try collectKeyProps(allocator, tree, child, &keys);
    }

    try reportDuplicateKeys(allocator, diagnostics, tree, keys.items);
}

fn checkIteratorCallback(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    callback_index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const current = unwrapTransparent(tree, callback_index);
    switch (tree.data(current)) {
        .arrow_function_expression => |function| {
            if (function.expression) {
                try checkIteratorExpression(allocator, diagnostics, tree, function.body, options);
            } else {
                try checkFunctionBody(allocator, diagnostics, tree, function.body, options);
            }
        },
        .function => |function| {
            if (function.type != .function_expression or function.body == .null) return;
            try checkFunctionBody(allocator, diagnostics, tree, function.body, options);
        },
        else => {},
    }
}

fn checkIteratorExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const current = unwrapTransparent(tree, index);
    switch (tree.data(current)) {
        .jsx_element => |element| try checkIteratorElement(allocator, diagnostics, tree, element, current, options),
        .jsx_fragment => if (options.check_fragment_shorthand) {
            try report(allocator, diagnostics, tree, current, missing_iter_key_message);
        },
        .conditional_expression => |conditional| {
            try checkIteratorExpression(allocator, diagnostics, tree, conditional.consequent, options);
            try checkIteratorExpression(allocator, diagnostics, tree, conditional.alternate, options);
        },
        .logical_expression => |logical| try checkIteratorExpression(allocator, diagnostics, tree, logical.right, options),
        else => {},
    }
}

fn checkFunctionBody(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const body = switch (tree.data(index)) {
        .function_body => |body| body.body,
        .block_statement => |block| block.body,
        else => return,
    };
    try checkReturnStatements(allocator, diagnostics, tree, body, options);
}

fn checkReturnStatements(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    range: ast.IndexRange,
    options: Options,
) Allocator.Error!void {
    for (tree.extra(range)) |statement_index| {
        try checkReturnStatement(allocator, diagnostics, tree, statement_index, options);
    }
}

fn checkReturnStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    switch (tree.data(index)) {
        .return_statement => |statement| {
            if (statement.argument != .null) {
                try checkIteratorExpression(allocator, diagnostics, tree, statement.argument, options);
            }
        },
        .if_statement => |statement| {
            try checkReturnStatement(allocator, diagnostics, tree, statement.consequent, options);
            if (statement.alternate != .null) {
                try checkReturnStatement(allocator, diagnostics, tree, statement.alternate, options);
            }
        },
        .block_statement => |block| try checkReturnStatements(allocator, diagnostics, tree, block.body, options),
        else => {},
    }
}

fn checkIteratorElement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    element: ast.JSXElement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (hasKeyProp(tree, element, options)) return;
    try report(allocator, diagnostics, tree, index, missing_iter_key_message);
}

fn iteratorCallback(tree: *const ast.Tree, call: ast.CallExpression) ?ast.NodeIndex {
    const callee = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return null,
    };

    const method = propertyName(tree, callee.property) orelse return null;
    const arguments = tree.extra(call.arguments);
    if (std.mem.eql(u8, method, "map")) {
        if (arguments.len == 0) return null;
        return arguments[0];
    }

    if (!std.mem.eql(u8, method, "from")) return null;
    if (!isIdentifierReference(tree, callee.object, "Array")) return null;
    if (arguments.len <= 1) return null;
    return arguments[1];
}

fn hasKeyProp(tree: *const ast.Tree, element: ast.JSXElement, options: Options) bool {
    const opening = switch (tree.data(element.opening_element)) {
        .jsx_opening_element => |opening| opening,
        else => return false,
    };
    var seen_spread = false;
    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            .jsx_spread_attribute => {
                seen_spread = true;
                continue;
            },
            else => continue,
        };
        const name = jsxIdentifierName(tree, attribute.name) orelse continue;
        if (std.mem.eql(u8, name, "key")) {
            return !options.check_key_must_before_spread or !seen_spread;
        }
    }
    return false;
}

fn collectKeyProps(
    allocator: Allocator,
    tree: *const ast.Tree,
    element: ast.JSXElement,
    keys: *std.ArrayList(KeyProp),
) Allocator.Error!void {
    const opening = switch (tree.data(element.opening_element)) {
        .jsx_opening_element => |opening| opening,
        else => return,
    };

    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = jsxIdentifierName(tree, attribute.name) orelse continue;
        if (!std.mem.eql(u8, name, "key")) continue;
        const value = if (attribute.value == .null) "" else sourceForNode(tree, attribute.value);
        try keys.append(allocator, .{
            .value = value,
            .node = attribute_index,
        });
    }
}

fn reportDuplicateKeys(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    keys: []const KeyProp,
) Allocator.Error!void {
    for (keys, 0..) |key, index| {
        if (!hasDuplicateKeyValue(keys, index, key.value)) continue;
        try report(allocator, diagnostics, tree, key.node, non_unique_key_message);
    }
}

fn hasDuplicateKeyValue(keys: []const KeyProp, current_index: usize, value: []const u8) bool {
    for (keys, 0..) |key, index| {
        if (index == current_index) continue;
        if (std.mem.eql(u8, key.value, value)) return true;
    }
    return false;
}

fn sourceForNode(tree: *const ast.Tree, index: ast.NodeIndex) []const u8 {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start >= end or end > tree.source.len) return "";
    return tree.source[start..end];
}

fn isChildrenToArrayCall(tree: *const ast.Tree, call: ast.CallExpression, state: State) bool {
    const callee = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    const method = propertyName(tree, callee.property) orelse return false;
    if (!std.mem.eql(u8, method, "toArray")) return false;

    const object = unwrapTransparent(tree, callee.object);
    if (isIdentifierReference(tree, object, "Children")) return true;

    const member = switch (tree.data(object)) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member.property) orelse return false;
    if (!std.mem.eql(u8, property, "Children")) return false;
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

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn jsxIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierReference(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    const current = unwrapTransparent(tree, index);
    const name = switch (tree.data(current)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => return false,
    };
    return std.mem.eql(u8, name, expected);
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
