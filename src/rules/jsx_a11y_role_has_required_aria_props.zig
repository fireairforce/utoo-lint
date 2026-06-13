const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jsx-a11y/role-has-required-aria-props";

const RequiredRole = struct {
    role: []const u8,
    props: []const []const u8,
    props_message: []const u8,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
) Allocator.Error!void {
    const tag_name = elementName(tree, opening.name) orelse return;
    if (!isDomElement(tag_name)) return;

    const role_attribute = attributeNamed(tree, opening, "role") orelse return;
    const role_value = roleLiteralValue(tree, role_attribute.value) orelse return;
    if (isSemanticRoleElement(tree, opening, tag_name, role_value)) return;

    var roles = std.mem.splitScalar(u8, role_value, ' ');
    while (roles.next()) |role| {
        const required = requiredRole(role) orelse continue;
        if (hasAllRequiredProps(tree, opening, required.props)) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(role_attribute.name),
            "Elements with the ARIA role \"{s}\" must have the following attributes defined: {s}",
            .{ role, required.props_message },
        );
    }
}

fn hasAllRequiredProps(tree: *const ast.Tree, opening: ast.JSXOpeningElement, props: []const []const u8) bool {
    for (props) |prop| {
        if (attributeNamed(tree, opening, prop) == null) return false;
    }
    return true;
}

fn roleLiteralValue(tree: *const ast.Tree, value_index: ast.NodeIndex) ?[]const u8 {
    if (value_index == .null) return "true";
    return switch (tree.data(value_index)) {
        .string_literal => |literal| literalRoleValue(tree.string(literal.value)),
        .jsx_expression_container => |container| roleExpressionValue(tree, container.expression),
        else => null,
    };
}

fn roleExpressionValue(tree: *const ast.Tree, expression_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(expression_index)) {
        .string_literal => |literal| literalRoleValue(tree.string(literal.value)),
        .template_literal => |literal| templateRoleValue(tree, literal),
        .identifier_reference => |identifier| if (std.mem.eql(u8, tree.string(identifier.name), "undefined")) null else null,
        .boolean_literal => |literal| if (literal.value) "true" else "false",
        .null_literal => null,
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}

fn literalRoleValue(value: []const u8) []const u8 {
    if (std.ascii.eqlIgnoreCase(value, "true")) return "true";
    if (std.ascii.eqlIgnoreCase(value, "false")) return "false";
    return value;
}

fn templateRoleValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";
    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn isSemanticRoleElement(tree: *const ast.Tree, opening: ast.JSXOpeningElement, tag_name: []const u8, role: []const u8) bool {
    if (std.mem.eql(u8, tag_name, "input")) {
        const typ = attributeNamed(tree, opening, "type") orelse return false;
        const type_value = literalStringValue(tree, typ.value) orelse return false;
        if (std.ascii.eqlIgnoreCase(type_value, "checkbox")) {
            return std.mem.eql(u8, role, "checkbox") or std.mem.eql(u8, role, "switch");
        }
        if (std.ascii.eqlIgnoreCase(type_value, "radio")) {
            return std.mem.eql(u8, role, "radio");
        }
        return false;
    }

    if (std.mem.eql(u8, tag_name, "select")) {
        if (attributeNamed(tree, opening, "multiple") != null) return std.mem.eql(u8, role, "listbox");
        return std.mem.eql(u8, role, "combobox");
    }

    if (std.mem.eql(u8, tag_name, "progress")) return std.mem.eql(u8, role, "progressbar");
    if (std.mem.eql(u8, tag_name, "meter")) return std.mem.eql(u8, role, "meter");
    return false;
}

fn literalStringValue(tree: *const ast.Tree, value_index: ast.NodeIndex) ?[]const u8 {
    if (value_index == .null) return null;
    return switch (tree.data(value_index)) {
        .string_literal => |literal| tree.string(literal.value),
        .jsx_expression_container => |container| switch (tree.data(container.expression)) {
            .string_literal => |literal| tree.string(literal.value),
            else => null,
        },
        else => null,
    };
}

fn requiredRole(role: []const u8) ?RequiredRole {
    for (required_roles) |required| {
        if (std.mem.eql(u8, role, required.role)) return required;
    }
    return null;
}

fn attributeNamed(tree: *const ast.Tree, opening: ast.JSXOpeningElement, expected: []const u8) ?ast.JSXAttribute {
    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = attributeName(tree, attribute.name) orelse continue;
        if (std.ascii.eqlIgnoreCase(name, expected)) return attribute;
    }
    return null;
}

fn elementName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn attributeName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isDomElement(name: []const u8) bool {
    for (dom_elements) |element| {
        if (std.mem.eql(u8, name, element)) return true;
    }
    return false;
}

const props_aria_checked = [_][]const u8{"aria-checked"};
const props_combobox = [_][]const u8{ "aria-controls", "aria-expanded" };
const props_aria_level = [_][]const u8{"aria-level"};
const props_meter = [_][]const u8{"aria-valuenow"};
const props_aria_selected = [_][]const u8{"aria-selected"};
const props_scrollbar = [_][]const u8{ "aria-controls", "aria-valuenow" };

const required_roles = [_]RequiredRole{
    .{ .role = "checkbox", .props = &props_aria_checked, .props_message = "aria-checked" },
    .{ .role = "combobox", .props = &props_combobox, .props_message = "aria-controls,aria-expanded" },
    .{ .role = "heading", .props = &props_aria_level, .props_message = "aria-level" },
    .{ .role = "menuitemcheckbox", .props = &props_aria_checked, .props_message = "aria-checked" },
    .{ .role = "menuitemradio", .props = &props_aria_checked, .props_message = "aria-checked" },
    .{ .role = "meter", .props = &props_meter, .props_message = "aria-valuenow" },
    .{ .role = "option", .props = &props_aria_selected, .props_message = "aria-selected" },
    .{ .role = "radio", .props = &props_aria_checked, .props_message = "aria-checked" },
    .{ .role = "scrollbar", .props = &props_scrollbar, .props_message = "aria-controls,aria-valuenow" },
    .{ .role = "slider", .props = &props_meter, .props_message = "aria-valuenow" },
    .{ .role = "switch", .props = &props_aria_checked, .props_message = "aria-checked" },
    .{ .role = "treeitem", .props = &props_aria_selected, .props_message = "aria-selected" },
};

const dom_elements = [_][]const u8{
    "a",
    "abbr",
    "acronym",
    "address",
    "applet",
    "area",
    "article",
    "aside",
    "audio",
    "b",
    "base",
    "bdi",
    "bdo",
    "big",
    "blink",
    "blockquote",
    "body",
    "br",
    "button",
    "canvas",
    "caption",
    "center",
    "cite",
    "code",
    "col",
    "colgroup",
    "content",
    "data",
    "datalist",
    "dd",
    "del",
    "details",
    "dfn",
    "dialog",
    "dir",
    "div",
    "dl",
    "dt",
    "em",
    "embed",
    "fieldset",
    "figcaption",
    "figure",
    "font",
    "footer",
    "form",
    "frame",
    "frameset",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "head",
    "header",
    "hgroup",
    "hr",
    "html",
    "i",
    "iframe",
    "img",
    "input",
    "ins",
    "kbd",
    "keygen",
    "label",
    "legend",
    "li",
    "link",
    "main",
    "map",
    "mark",
    "marquee",
    "menu",
    "menuitem",
    "meta",
    "meter",
    "nav",
    "noembed",
    "noscript",
    "object",
    "ol",
    "optgroup",
    "option",
    "output",
    "p",
    "param",
    "picture",
    "pre",
    "progress",
    "q",
    "rp",
    "rt",
    "rtc",
    "ruby",
    "s",
    "samp",
    "script",
    "section",
    "select",
    "small",
    "source",
    "spacer",
    "span",
    "strike",
    "strong",
    "style",
    "sub",
    "summary",
    "sup",
    "table",
    "tbody",
    "td",
    "textarea",
    "tfoot",
    "th",
    "thead",
    "time",
    "title",
    "tr",
    "track",
    "tt",
    "u",
    "ul",
    "var",
    "video",
    "wbr",
    "xmp",
};
