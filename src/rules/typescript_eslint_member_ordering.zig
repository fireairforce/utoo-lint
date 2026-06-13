const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/member-ordering";

const MemberKind = enum {
    field,
    method,
    constructor,
};

const MemberInfo = struct {
    name: []const u8,
    rank: u8,
    phrase: []const u8,
    span: ast.Span,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.ClassBody,
) Allocator.Error!void {
    var latest: ?MemberInfo = null;

    for (tree.extra(body.body)) |member_index| {
        const current = memberInfo(tree, member_index) orelse continue;
        if (latest) |previous| {
            if (current.rank < previous.rank) {
                try core.addDiagnosticFmt(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    current.span,
                    "Member {s} should be declared before all {s}.",
                    .{ current.name, previous.phrase },
                );
            }
        }

        if (latest == null or current.rank > latest.?.rank) {
            latest = current;
        }
    }
}

fn memberInfo(tree: *const ast.Tree, index: ast.NodeIndex) ?MemberInfo {
    return switch (tree.data(index)) {
        .property_definition => |property| memberInfoFromParts(
            tree,
            property.key,
            property.computed,
            property.static,
            property.accessibility,
            .field,
        ),
        .method_definition => |method| memberInfoFromParts(
            tree,
            method.key,
            method.computed,
            method.static,
            method.accessibility,
            if (method.kind == .constructor) .constructor else .method,
        ),
        else => null,
    };
}

fn memberInfoFromParts(
    tree: *const ast.Tree,
    key: ast.NodeIndex,
    computed: bool,
    is_static: bool,
    accessibility: ast.Accessibility,
    kind: MemberKind,
) ?MemberInfo {
    if (computed) return null;
    const name = if (kind == .constructor) "constructor" else keyName(tree, key) orelse return null;
    const access = if (accessibility == .none) .public else accessibility;
    return .{
        .name = name,
        .rank = memberRank(access, is_static, kind),
        .phrase = memberPhrase(access, is_static, kind),
        .span = tree.span(key),
    };
}

fn memberRank(accessibility: ast.Accessibility, is_static: bool, kind: MemberKind) u8 {
    if (kind == .constructor) return 16;

    if (is_static) {
        return switch (kind) {
            .field => switch (accessibility) {
                .public, .none => 0,
                .protected => 1,
                .private => 2,
            },
            .method => switch (accessibility) {
                .public, .none => 4,
                .protected => 5,
                .private => 6,
            },
            .constructor => unreachable,
        };
    }

    return switch (kind) {
        .field => switch (accessibility) {
            .public, .none => 8,
            .protected => 9,
            .private => 10,
        },
        .method => switch (accessibility) {
            .public, .none => 17,
            .protected => 18,
            .private => 19,
        },
        .constructor => unreachable,
    };
}

fn memberPhrase(accessibility: ast.Accessibility, is_static: bool, kind: MemberKind) []const u8 {
    if (kind == .constructor) return "constructor definitions";

    return switch (accessibility) {
        .public, .none => if (is_static)
            if (kind == .field) "public static field definitions" else "public static method definitions"
        else if (kind == .field) "public instance field definitions" else "public instance method definitions",
        .protected => if (is_static)
            if (kind == .field) "protected static field definitions" else "protected static method definitions"
        else if (kind == .field) "protected instance field definitions" else "protected instance method definitions",
        .private => if (is_static)
            if (kind == .field) "private static field definitions" else "private static method definitions"
        else if (kind == .field) "private instance field definitions" else "private instance method definitions",
    };
}

fn keyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .private_identifier => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}
