const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/ban-ts-comment";

pub const Options = struct {
    ts_expect_error: core.TypescriptEslintBanTsCommentMode = .allow_with_description,
    ts_ignore: core.TypescriptEslintBanTsCommentMode = .allow_with_description,
    ts_nocheck: core.TypescriptEslintBanTsCommentMode = .allow_with_description,
    ts_check: core.TypescriptEslintBanTsCommentMode = .allow_with_description,
    minimum_description_length: usize = 3,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    return runWithOptions(allocator, diagnostics, tree, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    options: Options,
) Allocator.Error!void {
    for (tree.comments) |comment| {
        const directive = directiveFromComment(tree, comment) orelse continue;
        switch (modeForDirective(options, directive.kind)) {
            .allow => continue,
            .ban => {},
            .allow_with_description => {
                if (descriptionLength(directive.description) >= options.minimum_description_length) continue;
                try core.addDiagnosticFmt(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    .{ .start = comment.start, .end = comment.end },
                    "Include a description after the \"@ts-{s}\" directive to explain why the @ts-{s} is necessary. The description must be {d} characters or longer.",
                    .{ directive.name, directive.name, options.minimum_description_length },
                );
                continue;
            },
        }

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            .{ .start = comment.start, .end = comment.end },
            "Do not use \"@ts-{s}\" directives.",
            .{directive.name},
        );
    }
}

const DirectiveKind = enum {
    ts_expect_error,
    ts_ignore,
    ts_nocheck,
    ts_check,
};

const Directive = struct {
    kind: DirectiveKind,
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

    inline for (.{
        .{ .kind = DirectiveKind.ts_expect_error, .name = "expect-error" },
        .{ .kind = DirectiveKind.ts_ignore, .name = "ignore" },
        .{ .kind = DirectiveKind.ts_nocheck, .name = "nocheck" },
        .{ .kind = DirectiveKind.ts_check, .name = "check" },
    }) |directive| {
        if (std.mem.startsWith(u8, after_prefix, directive.name)) {
            return .{
                .kind = directive.kind,
                .name = directive.name,
                .description = after_prefix[directive.name.len..],
            };
        }
    }

    return null;
}

fn modeForDirective(options: Options, kind: DirectiveKind) core.TypescriptEslintBanTsCommentMode {
    return switch (kind) {
        .ts_expect_error => options.ts_expect_error,
        .ts_ignore => options.ts_ignore,
        .ts_nocheck => options.ts_nocheck,
        .ts_check => options.ts_check,
    };
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
