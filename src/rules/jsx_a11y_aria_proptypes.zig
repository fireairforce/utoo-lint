const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jsx-a11y/aria-proptypes";

const AriaType = enum {
    boolean,
    string,
    id,
    tristate,
    integer,
    number,
    token,
    idlist,
    tokenlist,
};

const AriaSpec = struct {
    name: []const u8,
    typ: AriaType,
    values: []const AriaValue = &.{},
    values_message: []const u8 = "",
};

const AriaValue = union(enum) {
    string: []const u8,
    boolean: bool,
};

const LiteralValue = union(enum) {
    string: []const u8,
    boolean: bool,
    number: []const u8,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    attribute: ast.JSXAttribute,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const name = attributeName(tree, attribute.name) orelse return;
    const spec = ariaSpec(name) orelse return;
    const value = literalPropValue(tree, attribute.value) orelse return;
    if (isValidValue(value, spec)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, name, spec);
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    name: []const u8,
    spec: AriaSpec,
) Allocator.Error!void {
    switch (spec.typ) {
        .tristate => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "The value for {s} must be a boolean or the string \"mixed\".",
            .{name},
        ),
        .token => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "The value for {s} must be a single token from the following: {s}.",
            .{ name, spec.values_message },
        ),
        .tokenlist => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "The value for {s} must be a list of one or more tokens from the following: {s}.",
            .{ name, spec.values_message },
        ),
        .idlist => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "The value for {s} must be a list of strings that represent DOM element IDs (idlist)",
            .{name},
        ),
        .id => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "The value for {s} must be a string that represents a DOM element ID",
            .{name},
        ),
        .boolean => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "The value for {s} must be a boolean.",
            .{name},
        ),
        .string => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "The value for {s} must be a string.",
            .{name},
        ),
        .integer => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "The value for {s} must be a integer.",
            .{name},
        ),
        .number => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "The value for {s} must be a number.",
            .{name},
        ),
    }
}

fn literalPropValue(tree: *const ast.Tree, value_index: ast.NodeIndex) ?LiteralValue {
    if (value_index == .null) return .{ .boolean = true };

    return switch (tree.data(value_index)) {
        .string_literal => |literal| literalFromString(tree.string(literal.value)),
        .jsx_expression_container => |container| literalExpressionValue(tree, container.expression),
        else => null,
    };
}

fn literalExpressionValue(tree: *const ast.Tree, expression_index: ast.NodeIndex) ?LiteralValue {
    return switch (tree.data(expression_index)) {
        .string_literal => |literal| literalFromString(tree.string(literal.value)),
        .boolean_literal => |literal| .{ .boolean = literal.value },
        .numeric_literal => |literal| .{ .number = tree.string(literal.raw) },
        .template_literal => |literal| templateLiteralValue(tree, literal),
        .identifier_reference => |identifier| identifierLiteralValue(tree.string(identifier.name)),
        .null_literal => null,
        else => null,
    };
}

fn literalFromString(value: []const u8) LiteralValue {
    if (std.ascii.eqlIgnoreCase(value, "true")) return .{ .boolean = true };
    if (std.ascii.eqlIgnoreCase(value, "false")) return .{ .boolean = false };
    return .{ .string = value };
}

fn identifierLiteralValue(name: []const u8) ?LiteralValue {
    if (std.mem.eql(u8, name, "undefined")) return null;
    if (std.mem.eql(u8, name, "Infinity")) return .{ .number = "Infinity" };
    if (std.mem.eql(u8, name, "Array") or
        std.mem.eql(u8, name, "Date") or
        std.mem.eql(u8, name, "Math") or
        std.mem.eql(u8, name, "Number") or
        std.mem.eql(u8, name, "Object") or
        std.mem.eql(u8, name, "String"))
    {
        return .{ .string = "" };
    }
    return null;
}

fn templateLiteralValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?LiteralValue {
    if (literal.expressions.len != 0) return .{ .string = "{expression}" };

    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return .{ .string = "" };

    return switch (tree.data(quasis[0])) {
        .template_element => |element| literalFromString(tree.string(element.cooked)),
        else => null,
    };
}

fn isValidValue(value: LiteralValue, spec: AriaSpec) bool {
    return switch (spec.typ) {
        .boolean => std.meta.activeTag(value) == .boolean,
        .string, .id => std.meta.activeTag(value) == .string,
        .tristate => switch (value) {
            .boolean => true,
            .string => |string| std.mem.eql(u8, string, "mixed"),
            .number => false,
        },
        .integer, .number => std.meta.activeTag(value) != .boolean and isNumberLike(value),
        .token => tokenValueIsValid(value, spec.values),
        .idlist => std.meta.activeTag(value) == .string,
        .tokenlist => tokenListValueIsValid(value, spec.values),
    };
}

fn isNumberLike(value: LiteralValue) bool {
    const raw = switch (value) {
        .string => |string| string,
        .number => |number| number,
        .boolean => return false,
    };

    const trimmed = std.mem.trim(u8, raw, " \t\r\n");
    if (trimmed.len == 0) return true;
    if (std.mem.startsWith(u8, trimmed, "0x") or std.mem.startsWith(u8, trimmed, "0X")) {
        _ = std.fmt.parseInt(u64, trimmed[2..], 16) catch return false;
        return true;
    }
    _ = std.fmt.parseFloat(f64, trimmed) catch return false;
    return true;
}

fn tokenValueIsValid(value: LiteralValue, values: []const AriaValue) bool {
    for (values) |permitted| {
        if (ariaValueMatches(value, permitted)) return true;
    }
    return false;
}

fn tokenListValueIsValid(value: LiteralValue, values: []const AriaValue) bool {
    if (std.meta.activeTag(value) != .string) return false;

    var tokens = std.mem.splitScalar(u8, value.string, ' ');
    while (tokens.next()) |token| {
        if (!stringTokenIsValid(token, values)) return false;
    }
    return true;
}

fn stringTokenIsValid(token: []const u8, values: []const AriaValue) bool {
    for (values) |permitted| {
        switch (permitted) {
            .string => |string| if (std.ascii.eqlIgnoreCase(token, string)) return true,
            .boolean => {},
        }
    }
    return false;
}

fn ariaValueMatches(value: LiteralValue, permitted: AriaValue) bool {
    return switch (permitted) {
        .string => |string| switch (value) {
            .string => |value_string| std.ascii.eqlIgnoreCase(value_string, string),
            else => false,
        },
        .boolean => |boolean| switch (value) {
            .boolean => |value_boolean| value_boolean == boolean,
            else => false,
        },
    };
}

fn ariaSpec(name: []const u8) ?AriaSpec {
    if (name.len < "aria-".len or !std.ascii.eqlIgnoreCase(name[0.."aria-".len], "aria-")) return null;

    var lower_buffer: [64]u8 = undefined;
    const lower_name = lowerAttributeName(name, &lower_buffer) orelse return null;

    for (aria_specs) |spec| {
        if (std.mem.eql(u8, lower_name, spec.name)) return spec;
    }
    return null;
}

fn attributeName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn lowerAttributeName(name: []const u8, buffer: *[64]u8) ?[]const u8 {
    if (name.len > buffer.len) return null;
    for (name, 0..) |char, index| {
        buffer[index] = std.ascii.toLower(char);
    }
    return buffer[0..name.len];
}

const values_autocomplete = [_]AriaValue{
    .{ .string = "inline" },
    .{ .string = "list" },
    .{ .string = "both" },
    .{ .string = "none" },
};

const values_current = [_]AriaValue{
    .{ .string = "page" },
    .{ .string = "step" },
    .{ .string = "location" },
    .{ .string = "date" },
    .{ .string = "time" },
    .{ .boolean = true },
    .{ .boolean = false },
};

const values_dropeffect = [_]AriaValue{
    .{ .string = "copy" },
    .{ .string = "execute" },
    .{ .string = "link" },
    .{ .string = "move" },
    .{ .string = "none" },
    .{ .string = "popup" },
};

const values_haspopup = [_]AriaValue{
    .{ .boolean = false },
    .{ .boolean = true },
    .{ .string = "menu" },
    .{ .string = "listbox" },
    .{ .string = "tree" },
    .{ .string = "grid" },
    .{ .string = "dialog" },
};

const values_invalid = [_]AriaValue{
    .{ .string = "grammar" },
    .{ .boolean = false },
    .{ .string = "spelling" },
    .{ .boolean = true },
};

const values_live = [_]AriaValue{
    .{ .string = "assertive" },
    .{ .string = "off" },
    .{ .string = "polite" },
};

const values_orientation = [_]AriaValue{
    .{ .string = "vertical" },
    .{ .string = "undefined" },
    .{ .string = "horizontal" },
};

const values_relevant = [_]AriaValue{
    .{ .string = "additions" },
    .{ .string = "all" },
    .{ .string = "removals" },
    .{ .string = "text" },
};

const values_sort = [_]AriaValue{
    .{ .string = "ascending" },
    .{ .string = "descending" },
    .{ .string = "none" },
    .{ .string = "other" },
};

const aria_specs = [_]AriaSpec{
    .{ .name = "aria-activedescendant", .typ = .id },
    .{ .name = "aria-atomic", .typ = .boolean },
    .{ .name = "aria-autocomplete", .typ = .token, .values = &values_autocomplete, .values_message = "inline,list,both,none" },
    .{ .name = "aria-braillelabel", .typ = .string },
    .{ .name = "aria-brailleroledescription", .typ = .string },
    .{ .name = "aria-busy", .typ = .boolean },
    .{ .name = "aria-checked", .typ = .tristate },
    .{ .name = "aria-colcount", .typ = .integer },
    .{ .name = "aria-colindex", .typ = .integer },
    .{ .name = "aria-colspan", .typ = .integer },
    .{ .name = "aria-controls", .typ = .idlist },
    .{ .name = "aria-current", .typ = .token, .values = &values_current, .values_message = "page,step,location,date,time,true,false" },
    .{ .name = "aria-describedby", .typ = .idlist },
    .{ .name = "aria-description", .typ = .string },
    .{ .name = "aria-details", .typ = .id },
    .{ .name = "aria-disabled", .typ = .boolean },
    .{ .name = "aria-dropeffect", .typ = .tokenlist, .values = &values_dropeffect, .values_message = "copy,execute,link,move,none,popup" },
    .{ .name = "aria-errormessage", .typ = .id },
    .{ .name = "aria-expanded", .typ = .boolean },
    .{ .name = "aria-flowto", .typ = .idlist },
    .{ .name = "aria-grabbed", .typ = .boolean },
    .{ .name = "aria-haspopup", .typ = .token, .values = &values_haspopup, .values_message = "false,true,menu,listbox,tree,grid,dialog" },
    .{ .name = "aria-hidden", .typ = .boolean },
    .{ .name = "aria-invalid", .typ = .token, .values = &values_invalid, .values_message = "grammar,false,spelling,true" },
    .{ .name = "aria-keyshortcuts", .typ = .string },
    .{ .name = "aria-label", .typ = .string },
    .{ .name = "aria-labelledby", .typ = .idlist },
    .{ .name = "aria-level", .typ = .integer },
    .{ .name = "aria-live", .typ = .token, .values = &values_live, .values_message = "assertive,off,polite" },
    .{ .name = "aria-modal", .typ = .boolean },
    .{ .name = "aria-multiline", .typ = .boolean },
    .{ .name = "aria-multiselectable", .typ = .boolean },
    .{ .name = "aria-orientation", .typ = .token, .values = &values_orientation, .values_message = "vertical,undefined,horizontal" },
    .{ .name = "aria-owns", .typ = .idlist },
    .{ .name = "aria-placeholder", .typ = .string },
    .{ .name = "aria-posinset", .typ = .integer },
    .{ .name = "aria-pressed", .typ = .tristate },
    .{ .name = "aria-readonly", .typ = .boolean },
    .{ .name = "aria-relevant", .typ = .tokenlist, .values = &values_relevant, .values_message = "additions,all,removals,text" },
    .{ .name = "aria-required", .typ = .boolean },
    .{ .name = "aria-roledescription", .typ = .string },
    .{ .name = "aria-rowcount", .typ = .integer },
    .{ .name = "aria-rowindex", .typ = .integer },
    .{ .name = "aria-rowspan", .typ = .integer },
    .{ .name = "aria-selected", .typ = .boolean },
    .{ .name = "aria-setsize", .typ = .integer },
    .{ .name = "aria-sort", .typ = .token, .values = &values_sort, .values_message = "ascending,descending,none,other" },
    .{ .name = "aria-valuemax", .typ = .number },
    .{ .name = "aria-valuemin", .typ = .number },
    .{ .name = "aria-valuenow", .typ = .number },
    .{ .name = "aria-valuetext", .typ = .string },
};
