const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-dupe-class-members";

const MemberKind = enum {
    constructor,
    method_or_field,
    get,
    set,
};

const Member = struct {
    name: []const u8,
    static: bool,
    kind: MemberKind,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.ClassBody,
) Allocator.Error!void {
    var members: std.ArrayList(Member) = .empty;
    defer members.deinit(allocator);

    for (tree.extra(body.body)) |member_index| {
        const member = memberInfo(tree, member_index) orelse continue;
        if (!isDuplicate(members.items, member)) {
            try members.append(allocator, member);
            continue;
        }

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Duplicate class member.",
            tree.span(member_index),
        );
    }
}

fn isDuplicate(existing_members: []const Member, candidate: Member) bool {
    for (existing_members) |existing| {
        if (existing.static != candidate.static) continue;
        if (!std.mem.eql(u8, existing.name, candidate.name)) continue;

        if ((existing.kind == .get and candidate.kind == .set) or
            (existing.kind == .set and candidate.kind == .get))
        {
            continue;
        }

        return true;
    }

    return false;
}

fn memberInfo(tree: *const ast.Tree, index: ast.NodeIndex) ?Member {
    return switch (tree.data(index)) {
        .method_definition => |method| methodInfo(tree, method),
        .property_definition => |property| propertyInfo(tree, property),
        else => null,
    };
}

fn methodInfo(tree: *const ast.Tree, method: ast.MethodDefinition) ?Member {
    const name = if (method.kind == .constructor and !method.static)
        "constructor"
    else
        staticKeyName(tree, method.key, method.computed) orelse return null;

    const kind: MemberKind = switch (method.kind) {
        .constructor => .constructor,
        .get => .get,
        .set => .set,
        .method => .method_or_field,
    };

    return .{ .name = name, .static = method.static, .kind = kind };
}

fn propertyInfo(tree: *const ast.Tree, property: ast.PropertyDefinition) ?Member {
    const name = staticKeyName(tree, property.key, property.computed) orelse return null;
    return .{ .name = name, .static = property.static, .kind = .method_or_field };
}

fn staticKeyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| if (computed) null else tree.string(identifier.name),
        .private_identifier => |identifier| if (computed) null else tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}
