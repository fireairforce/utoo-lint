const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-global-assign";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_assignment_expression(
        self: *Visitor,
        expression: ast.AssignmentExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkTarget(ctx.tree, expression.left);
        return .proceed;
    }

    pub fn enter_update_expression(
        self: *Visitor,
        expression: ast.UpdateExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkTarget(ctx.tree, expression.argument);
        return .proceed;
    }

    fn checkTarget(
        self: *Visitor,
        tree: *const ast.Tree,
        target: ast.NodeIndex,
    ) Allocator.Error!void {
        if (target == .null) return;

        const unwrapped = unwrapTransparent(tree, target);
        switch (tree.data(unwrapped)) {
            .identifier_reference => |identifier| try self.checkIdentifier(tree, identifier.name, unwrapped),
            .assignment_pattern => |pattern| try self.checkTarget(tree, pattern.left),
            .binding_rest_element => |element| try self.checkTarget(tree, element.argument),
            .array_pattern => |pattern| {
                for (tree.extra(pattern.elements)) |element| {
                    try self.checkTarget(tree, element);
                }
                try self.checkTarget(tree, pattern.rest);
            },
            .object_pattern => |pattern| {
                for (tree.extra(pattern.properties)) |property_index| {
                    const property = switch (tree.data(property_index)) {
                        .binding_property => |property| property,
                        else => continue,
                    };
                    try self.checkTarget(tree, property.value);
                }
                try self.checkTarget(tree, pattern.rest);
            },
            else => {},
        }
    }

    fn checkIdentifier(
        self: *Visitor,
        tree: *const ast.Tree,
        name_string: ast.String,
        node: ast.NodeIndex,
    ) Allocator.Error!void {
        const name = tree.string(name_string);
        if (!isReadonlyGlobal(name)) return;
        if (!isUnresolvedReference(self.symbol_table, node)) return;

        try core.addDiagnosticFmt(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            tree.span(node),
            "Read-only global '{s}' should not be modified.",
            .{name},
        );
    }
};

fn isReadonlyGlobal(name: []const u8) bool {
    if (name.len == 0) return false;

    return switch (name[0]) {
        'A' => isOneOf(name, .{ "Array", "ArrayBuffer" }),
        'B' => isOneOf(name, .{ "BigInt", "BigInt64Array", "BigUint64Array", "Boolean" }),
        'D' => isOneOf(name, .{ "DataView", "Date" }),
        'E' => isOneOf(name, .{ "Error", "EvalError" }),
        'F' => isOneOf(name, .{ "Float32Array", "Float64Array", "Function" }),
        'I' => isOneOf(name, .{ "Infinity", "Int8Array", "Int16Array", "Int32Array", "Intl" }),
        'J' => std.mem.eql(u8, name, "JSON"),
        'M' => isOneOf(name, .{ "Map", "Math" }),
        'N' => isOneOf(name, .{ "NaN", "Number" }),
        'O' => std.mem.eql(u8, name, "Object"),
        'P' => std.mem.eql(u8, name, "Promise"),
        'R' => isOneOf(name, .{ "RangeError", "ReferenceError", "Reflect", "RegExp" }),
        'S' => isOneOf(name, .{ "Set", "String", "Symbol", "SyntaxError" }),
        'T' => std.mem.eql(u8, name, "TypeError"),
        'U' => isOneOf(name, .{ "Uint8Array", "Uint8ClampedArray", "Uint16Array", "Uint32Array", "URIError" }),
        'W' => isOneOf(name, .{ "WeakMap", "WeakSet" }),
        'u' => std.mem.eql(u8, name, "undefined"),
        else => false,
    };
}

fn isOneOf(name: []const u8, comptime values: anytype) bool {
    inline for (values) |value| {
        if (std.mem.eql(u8, name, value)) return true;
    }
    return false;
}

fn isUnresolvedReference(
    symbol_table: traverser.semantic.SymbolTable,
    node: ast.NodeIndex,
) bool {
    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        if (entry.reference.node == node) {
            return symbol_table.referenceSymbol(entry.id) == .none;
        }
    }

    return false;
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
