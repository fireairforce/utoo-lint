const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const jsx_a11y_aria_props = @import("jsx_a11y_aria_props.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jsx-a11y/role-supports-aria-props";

const RoleSpec = struct {
    name: []const u8,
    extra_props: []const []const u8,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const tag_name = elementName(tree, opening.name) orelse return;
    const role_attribute = attributeNamed(tree, opening, "role");
    const role_value = if (role_attribute) |attribute|
        roleLiteralValue(tree, attribute.value) orelse return
    else
        implicitRole(tree, opening, tag_name) orelse return;
    const role = roleSpec(role_value) orelse return;
    const is_implicit = role_attribute == null;

    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = attributeName(tree, attribute.name) orelse continue;
        if (!jsx_a11y_aria_props.isValidAriaAttribute(name)) continue;
        if (!attributeHasDefinedValue(tree, attribute.value)) continue;
        if (roleSupportsProp(role, name)) continue;

        if (is_implicit) {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                tree.span(index),
                "The attribute {s} is not supported by the role {s}. This role is implicit on the element {s}.",
                .{ name, role.name, tag_name },
            );
        } else {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                tree.span(index),
                "The attribute {s} is not supported by the role {s}.",
                .{ name, role.name },
            );
        }
    }
}

fn roleSupportsProp(role: RoleSpec, prop: []const u8) bool {
    for (global_props) |global| {
        if (std.mem.eql(u8, prop, global)) return true;
    }
    for (role.extra_props) |extra| {
        if (std.mem.eql(u8, prop, extra)) return true;
    }
    return false;
}

fn roleSpec(role_name: []const u8) ?RoleSpec {
    for (roles) |role| {
        if (std.mem.eql(u8, role_name, role.name)) return role;
    }
    return null;
}

fn roleLiteralValue(tree: *const ast.Tree, value_index: ast.NodeIndex) ?[]const u8 {
    if (value_index == .null) return null;
    return switch (tree.data(value_index)) {
        .string_literal => |literal| tree.string(literal.value),
        .jsx_expression_container => |container| roleExpressionValue(tree, container.expression),
        else => null,
    };
}

fn roleExpressionValue(tree: *const ast.Tree, expression_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(expression_index)) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";
    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn attributeHasDefinedValue(tree: *const ast.Tree, value_index: ast.NodeIndex) bool {
    if (value_index == .null) return true;
    return switch (tree.data(value_index)) {
        .jsx_expression_container => |container| expressionHasDefinedValue(tree, container.expression),
        else => true,
    };
}

fn expressionHasDefinedValue(tree: *const ast.Tree, expression_index: ast.NodeIndex) bool {
    return switch (tree.data(expression_index)) {
        .null_literal => false,
        .identifier_reference => |identifier| !std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        else => true,
    };
}

fn implicitRole(tree: *const ast.Tree, opening: ast.JSXOpeningElement, tag_name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, tag_name, "a") or std.mem.eql(u8, tag_name, "area") or std.mem.eql(u8, tag_name, "link")) {
        return if (attributeNamed(tree, opening, "href") != null) "link" else null;
    }
    if (std.mem.eql(u8, tag_name, "img")) return implicitImgRole(tree, opening);
    if (std.mem.eql(u8, tag_name, "input")) return implicitInputRole(tree, opening);
    if (std.mem.eql(u8, tag_name, "menu")) return implicitMenuRole(tree, opening);
    if (std.mem.eql(u8, tag_name, "menuitem")) return implicitMenuItemRole(tree, opening);

    for (implicit_roles) |entry| {
        if (std.mem.eql(u8, tag_name, entry.element)) return entry.role;
    }
    return null;
}

fn implicitImgRole(tree: *const ast.Tree, opening: ast.JSXOpeningElement) ?[]const u8 {
    if (attributeNamed(tree, opening, "alt")) |attribute| {
        if (literalStringValue(tree, attribute.value)) |alt| {
            if (alt.len == 0) return null;
        }
    }
    if (attributeNamed(tree, opening, "src")) |attribute| {
        if (literalStringValue(tree, attribute.value)) |src| {
            if (std.mem.indexOf(u8, src, ".svg") != null) return null;
        }
    }
    return "img";
}

fn implicitInputRole(tree: *const ast.Tree, opening: ast.JSXOpeningElement) []const u8 {
    const typ = if (attributeNamed(tree, opening, "type")) |attribute| literalStringValue(tree, attribute.value) orelse "" else return "textbox";
    if (std.ascii.eqlIgnoreCase(typ, "button") or
        std.ascii.eqlIgnoreCase(typ, "image") or
        std.ascii.eqlIgnoreCase(typ, "reset") or
        std.ascii.eqlIgnoreCase(typ, "submit")) return "button";
    if (std.ascii.eqlIgnoreCase(typ, "checkbox")) return "checkbox";
    if (std.ascii.eqlIgnoreCase(typ, "radio")) return "radio";
    if (std.ascii.eqlIgnoreCase(typ, "range")) return "slider";
    return "textbox";
}

fn implicitMenuRole(tree: *const ast.Tree, opening: ast.JSXOpeningElement) ?[]const u8 {
    const typ = if (attributeNamed(tree, opening, "type")) |attribute| literalStringValue(tree, attribute.value) orelse "" else return null;
    return if (std.ascii.eqlIgnoreCase(typ, "toolbar")) "toolbar" else null;
}

fn implicitMenuItemRole(tree: *const ast.Tree, opening: ast.JSXOpeningElement) ?[]const u8 {
    const typ = if (attributeNamed(tree, opening, "type")) |attribute| literalStringValue(tree, attribute.value) orelse "" else return null;
    if (std.ascii.eqlIgnoreCase(typ, "command")) return "menuitem";
    if (std.ascii.eqlIgnoreCase(typ, "checkbox")) return "menuitemcheckbox";
    if (std.ascii.eqlIgnoreCase(typ, "radio")) return "menuitemradio";
    return null;
}

fn literalStringValue(tree: *const ast.Tree, value_index: ast.NodeIndex) ?[]const u8 {
    if (value_index == .null) return null;
    return switch (tree.data(value_index)) {
        .string_literal => |literal| tree.string(literal.value),
        .jsx_expression_container => |container| switch (tree.data(container.expression)) {
            .string_literal => |literal| tree.string(literal.value),
            .template_literal => |literal| templateStringValue(tree, literal),
            else => null,
        },
        else => null,
    };
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

const ImplicitRole = struct {
    element: []const u8,
    role: []const u8,
};

const implicit_roles = [_]ImplicitRole{
    .{ .element = "article", .role = "article" },
    .{ .element = "aside", .role = "complementary" },
    .{ .element = "body", .role = "document" },
    .{ .element = "button", .role = "button" },
    .{ .element = "datalist", .role = "listbox" },
    .{ .element = "details", .role = "group" },
    .{ .element = "dialog", .role = "dialog" },
    .{ .element = "form", .role = "form" },
    .{ .element = "h1", .role = "heading" },
    .{ .element = "h2", .role = "heading" },
    .{ .element = "h3", .role = "heading" },
    .{ .element = "h4", .role = "heading" },
    .{ .element = "h5", .role = "heading" },
    .{ .element = "h6", .role = "heading" },
    .{ .element = "hr", .role = "separator" },
    .{ .element = "li", .role = "listitem" },
    .{ .element = "meter", .role = "progressbar" },
    .{ .element = "nav", .role = "navigation" },
    .{ .element = "ol", .role = "list" },
    .{ .element = "option", .role = "option" },
    .{ .element = "output", .role = "status" },
    .{ .element = "progress", .role = "progressbar" },
    .{ .element = "section", .role = "region" },
    .{ .element = "select", .role = "listbox" },
    .{ .element = "tbody", .role = "rowgroup" },
    .{ .element = "textarea", .role = "textbox" },
    .{ .element = "tfoot", .role = "rowgroup" },
    .{ .element = "thead", .role = "rowgroup" },
    .{ .element = "ul", .role = "list" },
};

const global_props = [_][]const u8{
    "aria-atomic",
    "aria-busy",
    "aria-controls",
    "aria-current",
    "aria-describedby",
    "aria-details",
    "aria-dropeffect",
    "aria-flowto",
    "aria-grabbed",
    "aria-hidden",
    "aria-keyshortcuts",
    "aria-label",
    "aria-labelledby",
    "aria-live",
    "aria-owns",
    "aria-relevant",
    "aria-roledescription",
};

const props_alertdialog = [_][]const u8{
    "aria-modal",
};
const props_application = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_article = [_][]const u8{
    "aria-posinset",
    "aria-setsize",
};
const props_button = [_][]const u8{
    "aria-disabled",
    "aria-expanded",
    "aria-haspopup",
    "aria-pressed",
};
const props_cell = [_][]const u8{
    "aria-colindex",
    "aria-colspan",
    "aria-rowindex",
    "aria-rowspan",
};
const props_checkbox = [_][]const u8{
    "aria-checked",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-invalid",
    "aria-readonly",
    "aria-required",
};
const props_columnheader = [_][]const u8{
    "aria-colindex",
    "aria-colspan",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
    "aria-readonly",
    "aria-required",
    "aria-rowindex",
    "aria-rowspan",
    "aria-selected",
    "aria-sort",
};
const props_combobox = [_][]const u8{
    "aria-activedescendant",
    "aria-autocomplete",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
    "aria-readonly",
    "aria-required",
};
const props_composite = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
};
const props_dialog = [_][]const u8{
    "aria-modal",
};
const props_doc_abstract = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_acknowledgments = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_afterword = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_appendix = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_backlink = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_biblioentry = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
    "aria-level",
    "aria-posinset",
    "aria-setsize",
};
const props_doc_bibliography = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_biblioref = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_chapter = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_colophon = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_conclusion = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_cover = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_credit = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_credits = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_dedication = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_endnote = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
    "aria-level",
    "aria-posinset",
    "aria-setsize",
};
const props_doc_endnotes = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_epigraph = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_epilogue = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_errata = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_example = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_footnote = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_foreword = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_glossary = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_glossref = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_index = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_introduction = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_noteref = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_notice = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_pagebreak = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
    "aria-orientation",
    "aria-valuemax",
    "aria-valuemin",
    "aria-valuenow",
    "aria-valuetext",
};
const props_doc_pagefooter = [_][]const u8{
    "aria-braillelabel",
    "aria-brailleroledescription",
    "aria-description",
    "aria-disabled",
    "aria-errormessage",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_pageheader = [_][]const u8{
    "aria-braillelabel",
    "aria-brailleroledescription",
    "aria-description",
    "aria-disabled",
    "aria-errormessage",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_pagelist = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_part = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_preface = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_prologue = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_qna = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_subtitle = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_tip = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_doc_toc = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_graphics_document = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_graphics_object = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_graphics_symbol = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
};
const props_grid = [_][]const u8{
    "aria-activedescendant",
    "aria-colcount",
    "aria-disabled",
    "aria-multiselectable",
    "aria-readonly",
    "aria-rowcount",
};
const props_gridcell = [_][]const u8{
    "aria-colindex",
    "aria-colspan",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
    "aria-readonly",
    "aria-required",
    "aria-rowindex",
    "aria-rowspan",
    "aria-selected",
};
const props_group = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
};
const props_heading = [_][]const u8{
    "aria-level",
};
const props_input = [_][]const u8{
    "aria-disabled",
};
const props_link = [_][]const u8{
    "aria-disabled",
    "aria-expanded",
    "aria-haspopup",
};
const props_listbox = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-invalid",
    "aria-multiselectable",
    "aria-orientation",
    "aria-readonly",
    "aria-required",
};
const props_listitem = [_][]const u8{
    "aria-level",
    "aria-posinset",
    "aria-setsize",
};
const props_mark = [_][]const u8{
    "aria-braillelabel",
    "aria-brailleroledescription",
    "aria-description",
};
const props_menu = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-orientation",
};
const props_menubar = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-orientation",
};
const props_menuitem = [_][]const u8{
    "aria-disabled",
    "aria-expanded",
    "aria-haspopup",
    "aria-posinset",
    "aria-setsize",
};
const props_menuitemcheckbox = [_][]const u8{
    "aria-checked",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
    "aria-posinset",
    "aria-readonly",
    "aria-required",
    "aria-setsize",
};
const props_menuitemradio = [_][]const u8{
    "aria-checked",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
    "aria-posinset",
    "aria-readonly",
    "aria-required",
    "aria-setsize",
};
const props_meter = [_][]const u8{
    "aria-valuemax",
    "aria-valuemin",
    "aria-valuenow",
    "aria-valuetext",
};
const props_option = [_][]const u8{
    "aria-checked",
    "aria-disabled",
    "aria-posinset",
    "aria-selected",
    "aria-setsize",
};
const props_progressbar = [_][]const u8{
    "aria-valuemax",
    "aria-valuemin",
    "aria-valuenow",
    "aria-valuetext",
};
const props_radio = [_][]const u8{
    "aria-checked",
    "aria-disabled",
    "aria-posinset",
    "aria-setsize",
};
const props_radiogroup = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-errormessage",
    "aria-invalid",
    "aria-orientation",
    "aria-readonly",
    "aria-required",
};
const props_range = [_][]const u8{
    "aria-valuemax",
    "aria-valuemin",
    "aria-valuenow",
};
const props_row = [_][]const u8{
    "aria-activedescendant",
    "aria-colindex",
    "aria-disabled",
    "aria-expanded",
    "aria-level",
    "aria-posinset",
    "aria-rowindex",
    "aria-selected",
    "aria-setsize",
};
const props_rowheader = [_][]const u8{
    "aria-colindex",
    "aria-colspan",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-haspopup",
    "aria-invalid",
    "aria-readonly",
    "aria-required",
    "aria-rowindex",
    "aria-rowspan",
    "aria-selected",
    "aria-sort",
};
const props_scrollbar = [_][]const u8{
    "aria-disabled",
    "aria-orientation",
    "aria-valuemax",
    "aria-valuemin",
    "aria-valuenow",
    "aria-valuetext",
};
const props_searchbox = [_][]const u8{
    "aria-activedescendant",
    "aria-autocomplete",
    "aria-disabled",
    "aria-errormessage",
    "aria-haspopup",
    "aria-invalid",
    "aria-multiline",
    "aria-placeholder",
    "aria-readonly",
    "aria-required",
};
const props_select = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-orientation",
};
const props_separator = [_][]const u8{
    "aria-disabled",
    "aria-orientation",
    "aria-valuemax",
    "aria-valuemin",
    "aria-valuenow",
    "aria-valuetext",
};
const props_slider = [_][]const u8{
    "aria-disabled",
    "aria-errormessage",
    "aria-haspopup",
    "aria-invalid",
    "aria-orientation",
    "aria-readonly",
    "aria-valuemax",
    "aria-valuemin",
    "aria-valuenow",
    "aria-valuetext",
};
const props_spinbutton = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-errormessage",
    "aria-invalid",
    "aria-readonly",
    "aria-required",
    "aria-valuemax",
    "aria-valuemin",
    "aria-valuenow",
    "aria-valuetext",
};
const props_switch = [_][]const u8{
    "aria-checked",
    "aria-disabled",
    "aria-errormessage",
    "aria-expanded",
    "aria-invalid",
    "aria-readonly",
    "aria-required",
};
const props_tab = [_][]const u8{
    "aria-disabled",
    "aria-expanded",
    "aria-haspopup",
    "aria-posinset",
    "aria-selected",
    "aria-setsize",
};
const props_table = [_][]const u8{
    "aria-colcount",
    "aria-rowcount",
};
const props_tablist = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-level",
    "aria-multiselectable",
    "aria-orientation",
};
const props_textbox = [_][]const u8{
    "aria-activedescendant",
    "aria-autocomplete",
    "aria-disabled",
    "aria-errormessage",
    "aria-haspopup",
    "aria-invalid",
    "aria-multiline",
    "aria-placeholder",
    "aria-readonly",
    "aria-required",
};
const props_toolbar = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-orientation",
};
const props_tree = [_][]const u8{
    "aria-activedescendant",
    "aria-disabled",
    "aria-errormessage",
    "aria-invalid",
    "aria-multiselectable",
    "aria-orientation",
    "aria-required",
};
const props_treegrid = [_][]const u8{
    "aria-activedescendant",
    "aria-colcount",
    "aria-disabled",
    "aria-errormessage",
    "aria-invalid",
    "aria-multiselectable",
    "aria-orientation",
    "aria-readonly",
    "aria-required",
    "aria-rowcount",
};
const props_treeitem = [_][]const u8{
    "aria-checked",
    "aria-disabled",
    "aria-expanded",
    "aria-haspopup",
    "aria-level",
    "aria-posinset",
    "aria-selected",
    "aria-setsize",
};
const props_window = [_][]const u8{
    "aria-modal",
};

const roles = [_]RoleSpec{
    .{ .name = "alert", .extra_props = &.{} },
    .{ .name = "alertdialog", .extra_props = &props_alertdialog },
    .{ .name = "application", .extra_props = &props_application },
    .{ .name = "article", .extra_props = &props_article },
    .{ .name = "banner", .extra_props = &.{} },
    .{ .name = "blockquote", .extra_props = &.{} },
    .{ .name = "button", .extra_props = &props_button },
    .{ .name = "caption", .extra_props = &.{} },
    .{ .name = "cell", .extra_props = &props_cell },
    .{ .name = "checkbox", .extra_props = &props_checkbox },
    .{ .name = "code", .extra_props = &.{} },
    .{ .name = "columnheader", .extra_props = &props_columnheader },
    .{ .name = "combobox", .extra_props = &props_combobox },
    .{ .name = "command", .extra_props = &.{} },
    .{ .name = "complementary", .extra_props = &.{} },
    .{ .name = "composite", .extra_props = &props_composite },
    .{ .name = "contentinfo", .extra_props = &.{} },
    .{ .name = "definition", .extra_props = &.{} },
    .{ .name = "deletion", .extra_props = &.{} },
    .{ .name = "dialog", .extra_props = &props_dialog },
    .{ .name = "directory", .extra_props = &.{} },
    .{ .name = "doc-abstract", .extra_props = &props_doc_abstract },
    .{ .name = "doc-acknowledgments", .extra_props = &props_doc_acknowledgments },
    .{ .name = "doc-afterword", .extra_props = &props_doc_afterword },
    .{ .name = "doc-appendix", .extra_props = &props_doc_appendix },
    .{ .name = "doc-backlink", .extra_props = &props_doc_backlink },
    .{ .name = "doc-biblioentry", .extra_props = &props_doc_biblioentry },
    .{ .name = "doc-bibliography", .extra_props = &props_doc_bibliography },
    .{ .name = "doc-biblioref", .extra_props = &props_doc_biblioref },
    .{ .name = "doc-chapter", .extra_props = &props_doc_chapter },
    .{ .name = "doc-colophon", .extra_props = &props_doc_colophon },
    .{ .name = "doc-conclusion", .extra_props = &props_doc_conclusion },
    .{ .name = "doc-cover", .extra_props = &props_doc_cover },
    .{ .name = "doc-credit", .extra_props = &props_doc_credit },
    .{ .name = "doc-credits", .extra_props = &props_doc_credits },
    .{ .name = "doc-dedication", .extra_props = &props_doc_dedication },
    .{ .name = "doc-endnote", .extra_props = &props_doc_endnote },
    .{ .name = "doc-endnotes", .extra_props = &props_doc_endnotes },
    .{ .name = "doc-epigraph", .extra_props = &props_doc_epigraph },
    .{ .name = "doc-epilogue", .extra_props = &props_doc_epilogue },
    .{ .name = "doc-errata", .extra_props = &props_doc_errata },
    .{ .name = "doc-example", .extra_props = &props_doc_example },
    .{ .name = "doc-footnote", .extra_props = &props_doc_footnote },
    .{ .name = "doc-foreword", .extra_props = &props_doc_foreword },
    .{ .name = "doc-glossary", .extra_props = &props_doc_glossary },
    .{ .name = "doc-glossref", .extra_props = &props_doc_glossref },
    .{ .name = "doc-index", .extra_props = &props_doc_index },
    .{ .name = "doc-introduction", .extra_props = &props_doc_introduction },
    .{ .name = "doc-noteref", .extra_props = &props_doc_noteref },
    .{ .name = "doc-notice", .extra_props = &props_doc_notice },
    .{ .name = "doc-pagebreak", .extra_props = &props_doc_pagebreak },
    .{ .name = "doc-pagefooter", .extra_props = &props_doc_pagefooter },
    .{ .name = "doc-pageheader", .extra_props = &props_doc_pageheader },
    .{ .name = "doc-pagelist", .extra_props = &props_doc_pagelist },
    .{ .name = "doc-part", .extra_props = &props_doc_part },
    .{ .name = "doc-preface", .extra_props = &props_doc_preface },
    .{ .name = "doc-prologue", .extra_props = &props_doc_prologue },
    .{ .name = "doc-pullquote", .extra_props = &.{} },
    .{ .name = "doc-qna", .extra_props = &props_doc_qna },
    .{ .name = "doc-subtitle", .extra_props = &props_doc_subtitle },
    .{ .name = "doc-tip", .extra_props = &props_doc_tip },
    .{ .name = "doc-toc", .extra_props = &props_doc_toc },
    .{ .name = "document", .extra_props = &.{} },
    .{ .name = "emphasis", .extra_props = &.{} },
    .{ .name = "feed", .extra_props = &.{} },
    .{ .name = "figure", .extra_props = &.{} },
    .{ .name = "form", .extra_props = &.{} },
    .{ .name = "generic", .extra_props = &.{} },
    .{ .name = "graphics-document", .extra_props = &props_graphics_document },
    .{ .name = "graphics-object", .extra_props = &props_graphics_object },
    .{ .name = "graphics-symbol", .extra_props = &props_graphics_symbol },
    .{ .name = "grid", .extra_props = &props_grid },
    .{ .name = "gridcell", .extra_props = &props_gridcell },
    .{ .name = "group", .extra_props = &props_group },
    .{ .name = "heading", .extra_props = &props_heading },
    .{ .name = "img", .extra_props = &.{} },
    .{ .name = "input", .extra_props = &props_input },
    .{ .name = "insertion", .extra_props = &.{} },
    .{ .name = "landmark", .extra_props = &.{} },
    .{ .name = "link", .extra_props = &props_link },
    .{ .name = "list", .extra_props = &.{} },
    .{ .name = "listbox", .extra_props = &props_listbox },
    .{ .name = "listitem", .extra_props = &props_listitem },
    .{ .name = "log", .extra_props = &.{} },
    .{ .name = "main", .extra_props = &.{} },
    .{ .name = "mark", .extra_props = &props_mark },
    .{ .name = "marquee", .extra_props = &.{} },
    .{ .name = "math", .extra_props = &.{} },
    .{ .name = "menu", .extra_props = &props_menu },
    .{ .name = "menubar", .extra_props = &props_menubar },
    .{ .name = "menuitem", .extra_props = &props_menuitem },
    .{ .name = "menuitemcheckbox", .extra_props = &props_menuitemcheckbox },
    .{ .name = "menuitemradio", .extra_props = &props_menuitemradio },
    .{ .name = "meter", .extra_props = &props_meter },
    .{ .name = "navigation", .extra_props = &.{} },
    .{ .name = "none", .extra_props = &.{} },
    .{ .name = "note", .extra_props = &.{} },
    .{ .name = "option", .extra_props = &props_option },
    .{ .name = "paragraph", .extra_props = &.{} },
    .{ .name = "presentation", .extra_props = &.{} },
    .{ .name = "progressbar", .extra_props = &props_progressbar },
    .{ .name = "radio", .extra_props = &props_radio },
    .{ .name = "radiogroup", .extra_props = &props_radiogroup },
    .{ .name = "range", .extra_props = &props_range },
    .{ .name = "region", .extra_props = &.{} },
    .{ .name = "roletype", .extra_props = &.{} },
    .{ .name = "row", .extra_props = &props_row },
    .{ .name = "rowgroup", .extra_props = &.{} },
    .{ .name = "rowheader", .extra_props = &props_rowheader },
    .{ .name = "scrollbar", .extra_props = &props_scrollbar },
    .{ .name = "search", .extra_props = &.{} },
    .{ .name = "searchbox", .extra_props = &props_searchbox },
    .{ .name = "section", .extra_props = &.{} },
    .{ .name = "sectionhead", .extra_props = &.{} },
    .{ .name = "select", .extra_props = &props_select },
    .{ .name = "separator", .extra_props = &props_separator },
    .{ .name = "slider", .extra_props = &props_slider },
    .{ .name = "spinbutton", .extra_props = &props_spinbutton },
    .{ .name = "status", .extra_props = &.{} },
    .{ .name = "strong", .extra_props = &.{} },
    .{ .name = "structure", .extra_props = &.{} },
    .{ .name = "subscript", .extra_props = &.{} },
    .{ .name = "superscript", .extra_props = &.{} },
    .{ .name = "switch", .extra_props = &props_switch },
    .{ .name = "tab", .extra_props = &props_tab },
    .{ .name = "table", .extra_props = &props_table },
    .{ .name = "tablist", .extra_props = &props_tablist },
    .{ .name = "tabpanel", .extra_props = &.{} },
    .{ .name = "term", .extra_props = &.{} },
    .{ .name = "textbox", .extra_props = &props_textbox },
    .{ .name = "time", .extra_props = &.{} },
    .{ .name = "timer", .extra_props = &.{} },
    .{ .name = "toolbar", .extra_props = &props_toolbar },
    .{ .name = "tooltip", .extra_props = &.{} },
    .{ .name = "tree", .extra_props = &props_tree },
    .{ .name = "treegrid", .extra_props = &props_treegrid },
    .{ .name = "treeitem", .extra_props = &props_treeitem },
    .{ .name = "widget", .extra_props = &.{} },
    .{ .name = "window", .extra_props = &props_window },
};
