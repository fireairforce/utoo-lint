const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/adjacent-overload-signatures";

const Member = struct {
    name: []const u8,
    static: bool = false,
    call_signature: bool = false,
};

pub fn checkRange(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    members: ast.IndexRange,
) Allocator.Error!void {
    var seen: std.ArrayList(Member) = .empty;
    defer seen.deinit(allocator);

    var last: ?Member = null;

    for (tree.extra(members)) |member_index| {
        const member = memberInfo(tree, member_index) orelse {
            last = null;
            continue;
        };

        if (seenIndex(seen.items, member)) |index| {
            if (!isSameMember(member, last)) {
                try addDiagnostic(allocator, diagnostics, tree, member_index, member);
            }
            _ = index;
        } else {
            try seen.append(allocator, member);
        }

        last = member;
    }
}

fn seenIndex(seen: []const Member, candidate: Member) ?usize {
    for (seen, 0..) |member, index| {
        if (isSameMember(candidate, member)) return index;
    }
    return null;
}

fn isSameMember(candidate: Member, existing: ?Member) bool {
    const member = existing orelse return false;
    return candidate.static == member.static and
        candidate.call_signature == member.call_signature and
        std.mem.eql(u8, candidate.name, member.name);
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    member: Member,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "All {s}{s} signatures should be adjacent.",
        .{ if (member.static) "static " else "", member.name },
    );
}

fn memberInfo(tree: *const ast.Tree, index: ast.NodeIndex) ?Member {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .export_named_declaration => |declaration| memberInfo(tree, declaration.declaration),
        .export_default_declaration => |declaration| memberInfo(tree, declaration.declaration),
        .function => |function| functionInfo(tree, function),
        .method_definition => |method| methodDefinitionInfo(tree, method),
        .ts_method_signature => |signature| methodSignatureInfo(tree, signature),
        .ts_call_signature_declaration => .{ .name = "call", .call_signature = true },
        .ts_construct_signature_declaration => .{ .name = "new" },
        else => null,
    };
}

fn functionInfo(tree: *const ast.Tree, function: ast.Function) ?Member {
    switch (function.type) {
        .function_declaration,
        .ts_declare_function,
        => {},
        else => return null,
    }

    const name = bindingIdentifierName(tree, function.id) orelse return null;
    return .{ .name = name };
}

fn methodDefinitionInfo(tree: *const ast.Tree, method: ast.MethodDefinition) ?Member {
    const name = if (method.kind == .constructor and !method.static)
        "constructor"
    else
        keyName(tree, method.key, method.computed) orelse return null;

    return .{ .name = name, .static = method.static };
}

fn methodSignatureInfo(tree: *const ast.Tree, signature: ast.TSMethodSignature) ?Member {
    const name = keyName(tree, signature.key, signature.computed) orelse return null;
    return .{ .name = name };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn keyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (computed or index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .private_identifier => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}
