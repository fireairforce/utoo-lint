const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jsx-a11y/aria-role";

const message = "Elements with ARIA roles must use a valid, non-abstract ARIA role.";

const RoleValueStatus = enum {
    valid,
    invalid,
    ignored,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
) Allocator.Error!void {
    const tag_name = elementName(tree, opening.name) orelse return;
    if (!isDomElement(tag_name)) return;

    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = attributeName(tree, attribute.name) orelse continue;
        if (!std.ascii.eqlIgnoreCase(name, "role")) continue;

        switch (roleValueStatus(tree, attribute.value)) {
            .valid, .ignored => {},
            .invalid => try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                message,
                tree.span(attribute_index),
            ),
        }
    }
}

fn roleValueStatus(tree: *const ast.Tree, value_index: ast.NodeIndex) RoleValueStatus {
    if (value_index == .null) return .invalid;

    return switch (tree.data(value_index)) {
        .string_literal => |literal| validateRoleList(tree.string(literal.value)),
        .jsx_expression_container => |container| roleExpressionStatus(tree, container.expression),
        else => .ignored,
    };
}

fn roleExpressionStatus(tree: *const ast.Tree, expression_index: ast.NodeIndex) RoleValueStatus {
    return switch (tree.data(expression_index)) {
        .string_literal => |literal| validateRoleList(tree.string(literal.value)),
        .template_literal => |literal| templateRoleStatus(tree, literal),
        .identifier_reference => |identifier| identifierRoleStatus(tree.string(identifier.name)),
        .boolean_literal,
        .null_literal,
        .numeric_literal,
        => .invalid,
        else => .ignored,
    };
}

fn templateRoleStatus(tree: *const ast.Tree, literal: ast.TemplateLiteral) RoleValueStatus {
    if (literal.expressions.len != 0) return .invalid;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return validateRoleList("");

    return switch (tree.data(quasis[0])) {
        .template_element => |element| validateRoleList(tree.string(element.cooked)),
        else => .ignored,
    };
}

fn identifierRoleStatus(name: []const u8) RoleValueStatus {
    if (std.mem.eql(u8, name, "undefined")) return .ignored;
    if (std.mem.eql(u8, name, "Array") or
        std.mem.eql(u8, name, "Date") or
        std.mem.eql(u8, name, "Infinity") or
        std.mem.eql(u8, name, "Math") or
        std.mem.eql(u8, name, "Number") or
        std.mem.eql(u8, name, "Object") or
        std.mem.eql(u8, name, "String"))
    {
        return .invalid;
    }
    return .ignored;
}

fn validateRoleList(value: []const u8) RoleValueStatus {
    var values = std.mem.splitScalar(u8, value, ' ');
    while (values.next()) |role| {
        if (!isValidRole(role)) return .invalid;
    }
    return .valid;
}

fn isValidRole(role: []const u8) bool {
    for (valid_roles) |valid_role| {
        if (std.mem.eql(u8, role, valid_role)) return true;
    }
    return false;
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

const valid_roles = [_][]const u8{
    "alert",
    "alertdialog",
    "application",
    "article",
    "banner",
    "blockquote",
    "button",
    "caption",
    "cell",
    "checkbox",
    "code",
    "columnheader",
    "combobox",
    "complementary",
    "contentinfo",
    "definition",
    "deletion",
    "dialog",
    "directory",
    "doc-abstract",
    "doc-acknowledgments",
    "doc-afterword",
    "doc-appendix",
    "doc-backlink",
    "doc-biblioentry",
    "doc-bibliography",
    "doc-biblioref",
    "doc-chapter",
    "doc-colophon",
    "doc-conclusion",
    "doc-cover",
    "doc-credit",
    "doc-credits",
    "doc-dedication",
    "doc-endnote",
    "doc-endnotes",
    "doc-epigraph",
    "doc-epilogue",
    "doc-errata",
    "doc-example",
    "doc-footnote",
    "doc-foreword",
    "doc-glossary",
    "doc-glossref",
    "doc-index",
    "doc-introduction",
    "doc-noteref",
    "doc-notice",
    "doc-pagebreak",
    "doc-pagefooter",
    "doc-pageheader",
    "doc-pagelist",
    "doc-part",
    "doc-preface",
    "doc-prologue",
    "doc-pullquote",
    "doc-qna",
    "doc-subtitle",
    "doc-tip",
    "doc-toc",
    "document",
    "emphasis",
    "feed",
    "figure",
    "form",
    "generic",
    "graphics-document",
    "graphics-object",
    "graphics-symbol",
    "grid",
    "gridcell",
    "group",
    "heading",
    "img",
    "insertion",
    "link",
    "list",
    "listbox",
    "listitem",
    "log",
    "main",
    "mark",
    "marquee",
    "math",
    "menu",
    "menubar",
    "menuitem",
    "menuitemcheckbox",
    "menuitemradio",
    "meter",
    "navigation",
    "none",
    "note",
    "option",
    "paragraph",
    "presentation",
    "progressbar",
    "radio",
    "radiogroup",
    "region",
    "row",
    "rowgroup",
    "rowheader",
    "scrollbar",
    "search",
    "searchbox",
    "separator",
    "slider",
    "spinbutton",
    "status",
    "strong",
    "subscript",
    "superscript",
    "switch",
    "tab",
    "table",
    "tablist",
    "tabpanel",
    "term",
    "textbox",
    "time",
    "timer",
    "toolbar",
    "tooltip",
    "tree",
    "treegrid",
    "treeitem",
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
