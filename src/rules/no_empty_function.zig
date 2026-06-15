const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-empty-function";

pub const Kind = enum {
    functions,
    arrowFunctions,
    generatorFunctions,
    asyncFunctions,
    methods,
    generatorMethods,
    asyncMethods,
    getters,
    setters,
    constructors,
};

pub const Options = struct {
    allow: core.NoEmptyFunctionAllow = .{},
    kind: Kind = .functions,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.FunctionBody,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, body, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.FunctionBody,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (body.body.len != 0) return;
    if (allowsKind(options.allow, options.kind)) return;
    if (hasCommentInsideBraces(tree, index)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected empty function.",
        tree.span(index),
    );
}

fn allowsKind(allow: core.NoEmptyFunctionAllow, kind: Kind) bool {
    return switch (kind) {
        .functions => allow.functions,
        .arrowFunctions => allow.arrowFunctions,
        .generatorFunctions => allow.generatorFunctions,
        .asyncFunctions => allow.asyncFunctions,
        .methods => allow.methods,
        .generatorMethods => allow.generatorMethods,
        .asyncMethods => allow.asyncMethods,
        .getters => allow.getters,
        .setters => allow.setters,
        .constructors => allow.constructors,
    };
}

pub fn hasCommentInsideBraces(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (tree.source.len == 0 or start >= end or end > tree.source.len) return false;

    const source = tree.source[start..end];
    const open = std.mem.indexOfScalar(u8, source, '{') orelse return false;
    const close = std.mem.lastIndexOfScalar(u8, source, '}') orelse return false;
    if (open >= close) return false;

    return containsOnlyWhitespaceAndHasComment(source[open + 1 .. close]);
}

fn containsOnlyWhitespaceAndHasComment(source: []const u8) bool {
    var has_comment = false;
    var index: usize = 0;

    while (index < source.len) {
        switch (source[index]) {
            ' ', '\t', '\n', '\r', 0x0B, 0x0C => index += 1,
            '/' => {
                if (index + 1 >= source.len) return false;

                switch (source[index + 1]) {
                    '/' => {
                        has_comment = true;
                        index += 2;
                        while (index < source.len and source[index] != '\n' and source[index] != '\r') {
                            index += 1;
                        }
                    },
                    '*' => {
                        has_comment = true;
                        index += 2;
                        var closed = false;
                        while (index + 1 < source.len) : (index += 1) {
                            if (source[index] == '*' and source[index + 1] == '/') {
                                index += 2;
                                closed = true;
                                break;
                            }
                        }
                        if (!closed) return false;
                    },
                    else => return false,
                }
            },
            else => return false,
        }
    }

    return has_comment;
}
