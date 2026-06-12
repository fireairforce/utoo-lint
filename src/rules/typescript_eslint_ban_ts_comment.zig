const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/ban-ts-comment";

const minimum_description_length = 3;

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    for (tree.comments) |comment| {
        const directive = directiveFromComment(tree, comment) orelse continue;
        if (descriptionLength(directive.description) >= minimum_description_length) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            .{ .start = comment.start, .end = comment.end },
            "Include a description after the \"@ts-{s}\" directive to explain why the @ts-{s} is necessary. The description must be {d} characters or longer.",
            .{ directive.name, directive.name, minimum_description_length },
        );
    }
}

const Directive = struct {
    name: []const u8,
    description: []const u8,
};

fn directiveFromComment(tree: *const ast.Tree, comment: ast.Comment) ?Directive {
    const value = tree.string(comment.value);
    const text = switch (comment.type) {
        .line => trimLeftSlashesAndWhitespace(value),
        .block => trimBlockPrefix(value),
    };

    if (!std.mem.startsWith(u8, text, "@ts-")) return null;
    const after_prefix = text["@ts-".len..];

    inline for (.{ "expect-error", "ignore", "nocheck", "check" }) |name| {
        if (std.mem.startsWith(u8, after_prefix, name)) {
            return .{
                .name = name,
                .description = after_prefix[name.len..],
            };
        }
    }

    return null;
}

fn trimLeftSlashesAndWhitespace(value: []const u8) []const u8 {
    var index: usize = 0;
    while (index < value.len) : (index += 1) {
        const char = value[index];
        if (char != '/' and !isWhitespace(char)) break;
    }
    return value[index..];
}

fn trimBlockPrefix(value: []const u8) []const u8 {
    var text = trimLeftWhitespace(value);
    while (text.len > 0 and (text[0] == '/' or text[0] == '*')) {
        text = trimLeftWhitespace(text[1..]);
    }
    return text;
}

fn descriptionLength(value: []const u8) usize {
    return std.mem.trim(u8, value, " \t\r\n").len;
}

fn trimLeftWhitespace(value: []const u8) []const u8 {
    var index: usize = 0;
    while (index < value.len and isWhitespace(value[index])) : (index += 1) {}
    return value[index..];
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n';
}
