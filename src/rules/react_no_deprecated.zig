const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-deprecated";

const Deprecated = struct {
    old: []const u8,
    version: []const u8,
    replacement: ?[]const u8 = null,
    refs: ?[]const u8 = null,
};

const deprecated = [_]Deprecated{
    .{ .old = "React.renderComponent", .version = "0.12.0", .replacement = "React.render" },
    .{ .old = "React.renderComponentToString", .version = "0.12.0", .replacement = "React.renderToString" },
    .{ .old = "React.renderComponentToStaticMarkup", .version = "0.12.0", .replacement = "React.renderToStaticMarkup" },
    .{ .old = "React.isValidComponent", .version = "0.12.0", .replacement = "React.isValidElement" },
    .{ .old = "React.PropTypes.component", .version = "0.12.0", .replacement = "React.PropTypes.element" },
    .{ .old = "React.PropTypes.renderable", .version = "0.12.0", .replacement = "React.PropTypes.node" },
    .{ .old = "React.isValidClass", .version = "0.12.0" },
    .{ .old = "this.transferPropsTo", .version = "0.12.0", .replacement = "spread operator ({...})" },
    .{ .old = "React.addons.classSet", .version = "0.13.0", .replacement = "the npm module classnames" },
    .{ .old = "React.addons.cloneWithProps", .version = "0.13.0", .replacement = "React.cloneElement" },
    .{ .old = "React.render", .version = "0.14.0", .replacement = "ReactDOM.render" },
    .{ .old = "React.unmountComponentAtNode", .version = "0.14.0", .replacement = "ReactDOM.unmountComponentAtNode" },
    .{ .old = "React.findDOMNode", .version = "0.14.0", .replacement = "ReactDOM.findDOMNode" },
    .{ .old = "React.renderToString", .version = "0.14.0", .replacement = "ReactDOMServer.renderToString" },
    .{ .old = "React.renderToStaticMarkup", .version = "0.14.0", .replacement = "ReactDOMServer.renderToStaticMarkup" },
    .{ .old = "React.addons.LinkedStateMixin", .version = "15.0.0" },
    .{ .old = "ReactPerf.printDOM", .version = "15.0.0", .replacement = "ReactPerf.printOperations" },
    .{ .old = "Perf.printDOM", .version = "15.0.0", .replacement = "Perf.printOperations" },
    .{ .old = "ReactPerf.getMeasurementsSummaryMap", .version = "15.0.0", .replacement = "ReactPerf.getWasted" },
    .{ .old = "Perf.getMeasurementsSummaryMap", .version = "15.0.0", .replacement = "Perf.getWasted" },
    .{ .old = "React.createClass", .version = "15.5.0", .replacement = "the npm module create-react-class" },
    .{ .old = "React.addons.TestUtils", .version = "15.5.0", .replacement = "ReactDOM.TestUtils" },
    .{ .old = "React.PropTypes", .version = "15.5.0", .replacement = "the npm module prop-types" },
    .{ .old = "React.DOM", .version = "15.6.0", .replacement = "the npm module react-dom-factories" },
    .{
        .old = "componentWillMount",
        .version = "16.9.0",
        .replacement = "UNSAFE_componentWillMount",
        .refs = "https://reactjs.org/docs/react-component.html#unsafe_componentwillmount. Use https://github.com/reactjs/react-codemod#rename-unsafe-lifecycles to automatically update your components.",
    },
    .{
        .old = "componentWillReceiveProps",
        .version = "16.9.0",
        .replacement = "UNSAFE_componentWillReceiveProps",
        .refs = "https://reactjs.org/docs/react-component.html#unsafe_componentwillreceiveprops. Use https://github.com/reactjs/react-codemod#rename-unsafe-lifecycles to automatically update your components.",
    },
    .{
        .old = "componentWillUpdate",
        .version = "16.9.0",
        .replacement = "UNSAFE_componentWillUpdate",
        .refs = "https://reactjs.org/docs/react-component.html#unsafe_componentwillupdate. Use https://github.com/reactjs/react-codemod#rename-unsafe-lifecycles to automatically update your components.",
    },
    .{ .old = "ReactDOM.render", .version = "18.0.0", .replacement = "createRoot", .refs = "https://reactjs.org/link/switch-to-createroot" },
    .{ .old = "ReactDOM.hydrate", .version = "18.0.0", .replacement = "hydrateRoot", .refs = "https://reactjs.org/link/switch-to-createroot" },
    .{ .old = "ReactDOM.unmountComponentAtNode", .version = "18.0.0", .replacement = "root.unmount", .refs = "https://reactjs.org/link/switch-to-createroot" },
    .{ .old = "ReactDOMServer.renderToNodeStream", .version = "18.0.0", .replacement = "renderToPipeableStream", .refs = "https://reactjs.org/docs/react-dom-server.html#rendertonodestream" },
};

const ModuleName = struct {
    source: []const u8,
    name: []const u8,
};

const modules = [_]ModuleName{
    .{ .source = "react", .name = "React" },
    .{ .source = "react-addons-perf", .name = "ReactPerf" },
    .{ .source = "react-addons-perf", .name = "Perf" },
    .{ .source = "react-dom", .name = "ReactDOM" },
    .{ .source = "react-dom/server", .name = "ReactDOMServer" },
};

pub fn checkProgram(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
) Allocator.Error!void {
    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        try checkImportDeclaration(allocator, diagnostics, tree, declaration);
    }
}

pub fn checkMemberExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const name = try memberExpressionName(allocator, tree, member);
    defer if (name) |value| allocator.free(value);

    if (name) |value| {
        try reportIfDeprecated(allocator, diagnostics, tree, index, value);
    }
}

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
) Allocator.Error!void {
    const pattern = switch (tree.data(declarator.id)) {
        .object_pattern => |pattern| pattern,
        else => return,
    };

    const module_name = reactModuleNameFromInit(tree, declarator.init) orelse return;

    for (tree.extra(pattern.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .binding_property => |property| property,
            else => continue,
        };
        const name = propertyName(tree, property.key) orelse continue;
        const old = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ module_name, name });
        defer allocator.free(old);
        try reportIfDeprecated(allocator, diagnostics, tree, property_index, old);
    }
}

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
) Allocator.Error!void {
    if (!isReactComponentClass(tree, class)) return;

    const body = switch (tree.data(class.body)) {
        .class_body => |body| body,
        else => return,
    };

    for (tree.extra(body.body)) |member_index| {
        const name = switch (tree.data(member_index)) {
            .method_definition => |method| propertyName(tree, method.key),
            .property_definition => |property| propertyName(tree, property.key),
            else => null,
        } orelse continue;
        try reportIfDeprecated(allocator, diagnostics, tree, member_index, name);
    }
}

pub fn checkObjectExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    object: ast.ObjectExpression,
    parent_index: ?ast.NodeIndex,
) Allocator.Error!void {
    if (!isCreateClassObject(tree, index, parent_index)) return;

    for (tree.extra(object.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        const name = propertyName(tree, property.key) orelse continue;
        try reportIfDeprecated(allocator, diagnostics, tree, property_index, name);
    }
}

fn checkImportDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
) Allocator.Error!void {
    const module_name = moduleNameFromSource(tree, declaration.source) orelse return;

    for (tree.extra(declaration.specifiers)) |specifier_index| {
        const specifier = switch (tree.data(specifier_index)) {
            .import_specifier => |specifier| specifier,
            else => continue,
        };
        const imported = propertyName(tree, specifier.imported) orelse continue;
        const old = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ module_name, imported });
        defer allocator.free(old);
        try reportIfDeprecated(allocator, diagnostics, tree, specifier_index, old);
    }
}

fn reportIfDeprecated(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    old: []const u8,
) Allocator.Error!void {
    const entry = deprecatedEntry(old) orelse return;

    if (entry.replacement) |replacement| {
        if (entry.refs) |refs| {
            return core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .@"error",
                id,
                tree.span(index),
                "{s} is deprecated since React {s}, use {s} instead, see {s}",
                .{ entry.old, entry.version, replacement, refs },
            );
        }
        return core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(index),
            "{s} is deprecated since React {s}, use {s} instead",
            .{ entry.old, entry.version, replacement },
        );
    }

    if (entry.refs) |refs| {
        return core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(index),
            "{s} is deprecated since React {s}, see {s}",
            .{ entry.old, entry.version, refs },
        );
    }

    return core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "{s} is deprecated since React {s}",
        .{ entry.old, entry.version },
    );
}

fn deprecatedEntry(old: []const u8) ?Deprecated {
    for (deprecated) |entry| {
        if (std.mem.eql(u8, entry.old, old)) return entry;
    }
    return null;
}

fn moduleNameFromSource(tree: *const ast.Tree, source_index: ast.NodeIndex) ?[]const u8 {
    const source = stringLiteralValue(tree, source_index) orelse return null;
    for (modules) |module| {
        if (std.mem.eql(u8, module.source, source)) return module.name;
    }
    return null;
}

fn reactModuleNameFromInit(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    const unwrapped = unwrapTransparent(tree, index);
    if (requireModuleName(tree, unwrapped)) |name| return name;

    const name = identifierReferenceName(tree, unwrapped) orelse return null;
    for (modules) |module| {
        if (std.mem.eql(u8, module.name, name)) return module.name;
    }
    return null;
}

fn requireModuleName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    const call = switch (tree.data(unwrapTransparent(tree, index))) {
        .call_expression => |call| call,
        else => return null,
    };
    if (!identifierReferenceEquals(tree, call.callee, "require")) return null;

    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return null;
    return moduleNameFromSource(tree, arguments[0]);
}

fn isCreateClassObject(tree: *const ast.Tree, index: ast.NodeIndex, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    const call = switch (tree.data(parent)) {
        .call_expression => |call| call,
        else => return false,
    };
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return false;
    if (arguments[0] != index) return false;
    return isCreateClassCallee(tree, call.callee);
}

fn isCreateClassCallee(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const callee = unwrapTransparent(tree, index);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createReactClass");
    }
    return false;
}

fn isReactComponentClass(tree: *const ast.Tree, class: ast.Class) bool {
    if (class.super_class == .null) return false;
    const super_class = unwrapTransparent(tree, class.super_class);

    if (identifierReferenceName(tree, super_class)) |name| {
        return std.mem.eql(u8, name, "Component") or std.mem.eql(u8, name, "PureComponent");
    }

    const member = switch (tree.data(super_class)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    if (!identifierReferenceEquals(tree, unwrapTransparent(tree, member.object), "React")) return false;
    const property = propertyName(tree, member.property) orelse return false;
    return std.mem.eql(u8, property, "Component") or std.mem.eql(u8, property, "PureComponent");
}

fn memberExpressionName(
    allocator: Allocator,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
) Allocator.Error!?[]const u8 {
    if (member.computed) return null;

    const object = try expressionName(allocator, tree, member.object);
    defer if (object) |value| allocator.free(value);
    const property = propertyName(tree, member.property) orelse return null;

    if (object) |object_name| {
        return try std.fmt.allocPrint(allocator, "{s}.{s}", .{ object_name, property });
    }
    return null;
}

fn expressionName(allocator: Allocator, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| try allocator.dupe(u8, tree.string(identifier.name)),
        .this_expression => try allocator.dupe(u8, "this"),
        .member_expression => |member| try memberExpressionName(allocator, tree, member),
        else => null,
    };
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceEquals(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    const name = identifierReferenceName(tree, index) orelse return false;
    return std.mem.eql(u8, name, expected);
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
