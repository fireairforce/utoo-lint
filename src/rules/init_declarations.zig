const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "init-declarations";

pub const Mode = enum {
    always,
    never,
};

pub const Options = struct {
    mode: Mode = .always,
    ignore_for_loop_init: bool = false,
};

pub const State = struct {
    declared_namespace_depth: usize = 0,
};

pub fn enterTSModuleDeclaration(state: *State, declaration: ast.TSModuleDeclaration) void {
    if (declaration.declare) {
        state.declared_namespace_depth += 1;
    }
}

pub fn exitTSModuleDeclaration(state: *State, declaration: ast.TSModuleDeclaration) void {
    if (declaration.declare and state.declared_namespace_depth > 0) {
        state.declared_namespace_depth -= 1;
    }
}

pub fn checkVariableDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    state: *const State,
    options: Options,
) Allocator.Error!void {
    if (declaration.declare) return;
    if (state.declared_namespace_depth > 0) return;

    const ignored_for_loop_init = options.ignore_for_loop_init and isForLoopInit(tree, index, ctx);

    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |declarator| declarator,
            else => continue,
        };
        const binding_name = bindingIdentifierName(tree, declarator.id) orelse continue;
        const initialized = isInitialized(tree, declarator, index, ctx);

        switch (options.mode) {
            .always => {
                if (!initialized) {
                    try report(allocator, diagnostics, tree, declarator.id, binding_name, .initialized);
                }
            },
            .never => {
                if (isConstLike(declaration.kind)) continue;
                if (ignored_for_loop_init) continue;
                if (initialized) {
                    try report(allocator, diagnostics, tree, declarator.id, binding_name, .not_initialized);
                }
            },
        }
    }
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isInitialized(
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    declaration_index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) bool {
    if (isForLoopInit(tree, declaration_index, ctx)) return true;
    return declarator.init != .null;
}

fn isForLoopInit(tree: *const ast.Tree, declaration_index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    const parent_index = ctx.path.ancestor(1) orelse return false;
    return switch (tree.data(parent_index)) {
        .for_statement => |statement| statement.init == declaration_index,
        .for_in_statement => |statement| statement.left == declaration_index,
        .for_of_statement => |statement| statement.left == declaration_index,
        else => false,
    };
}

fn isConstLike(kind: ast.VariableKind) bool {
    return switch (kind) {
        .@"const", .using, .await_using => true,
        .@"var", .let => false,
    };
}

const MessageKind = enum {
    initialized,
    not_initialized,
};

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    name: []const u8,
    kind: MessageKind,
) Allocator.Error!void {
    switch (kind) {
        .initialized => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Variable '{s}' should be initialized on declaration.",
            .{name},
        ),
        .not_initialized => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Variable '{s}' should not be initialized on declaration.",
            .{name},
        ),
    }
}
