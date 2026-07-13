const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/triple-slash-reference";

pub const Options = struct {
    path: core.TypescriptEslintTripleSlashReferenceMode = .never,
    types: core.TypescriptEslintTripleSlashReferenceMode = .always,
    lib: core.TypescriptEslintTripleSlashReferenceMode = .always,
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
        if (comment.type != .line) continue;

        const reference = referenceDirective(tree.string(comment.value)) orelse continue;
        if (isAllowed(reference, options)) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            .{ .start = comment.span.start, .end = comment.span.end },
            "Do not use a triple slash reference for {s}, use `import` style instead.",
            .{reference.value},
        );
    }
}

const ReferenceKind = enum {
    path,
    types,
    lib,
};

const Reference = struct {
    kind: ReferenceKind,
    value: []const u8,
};

fn referenceDirective(value: []const u8) ?Reference {
    if (value.len == 0 or value[0] != '/') return null;

    const body = trimLeftWhitespace(value[1..]);
    if (!std.mem.startsWith(u8, body, "<reference")) return null;

    const kind = referenceKind(body) orelse return null;
    const attribute = switch (kind) {
        .path => "path=",
        .types => "types=",
        .lib => "lib=",
    };
    const attribute_index = std.mem.indexOf(u8, body, attribute) orelse return null;
    var rest = body[attribute_index + attribute.len ..];
    rest = trimLeftWhitespace(rest);
    if (rest.len < 2) return null;

    const quote = rest[0];
    if (quote != '"' and quote != '\'') return null;
    const end = std.mem.indexOfScalar(u8, rest[1..], quote) orelse return null;
    return .{ .kind = kind, .value = rest[1..][0..end] };
}

fn referenceKind(body: []const u8) ?ReferenceKind {
    const path_index = std.mem.indexOf(u8, body, "path=");
    const types_index = std.mem.indexOf(u8, body, "types=");
    const lib_index = std.mem.indexOf(u8, body, "lib=");
    const path = path_index orelse body.len;
    const types = types_index orelse body.len;
    const lib = lib_index orelse body.len;

    if (path == body.len and types == body.len and lib == body.len) return null;
    if (path <= types and path <= lib) return .path;
    if (types <= path and types <= lib) return .types;
    return .lib;
}

fn isAllowed(reference: Reference, options: Options) bool {
    const mode = switch (reference.kind) {
        .path => options.path,
        .types => options.types,
        .lib => options.lib,
    };
    return mode == .always;
}

fn trimLeftWhitespace(value: []const u8) []const u8 {
    var index: usize = 0;
    while (index < value.len and (value[index] == ' ' or value[index] == '\t')) : (index += 1) {}
    return value[index..];
}
