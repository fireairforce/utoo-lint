const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/no-deprecated-dependence";

const Dep = struct {
    deprecated: []const u8,
    recommend: []const u8,
};

const default_deps = [_]Dep{
    .{ .deprecated = "@example/legacy-utils", .recommend = "@example/shared-utils" },
    .{ .deprecated = "@example/legacy-utils-next", .recommend = "@example/shared-utils" },
    .{ .deprecated = "@example/legacy-hooks", .recommend = "@example/shared-hooks" },
    .{ .deprecated = "@example/legacy-hooks-next", .recommend = "@example/shared-hooks" },
    .{ .deprecated = "@example/legacy-jsapi", .recommend = "appfw:jsapi" },
};

const profile_a_deps = [_]Dep{
    .{ .deprecated = "@example/share-react", .recommend = "jsapi share(原依赖包已不维护，体积也较大)" },
    .{ .deprecated = "@example/monitor-web", .recommend = "window.monitorClient(appfw 框架下，html 会默认注入 monitorClient 全局实例，无需安装额外依赖)" },
    .{ .deprecated = "@example/event-log", .recommend = "window.TraceClient(原依赖包已不维护)" },
    .{ .deprecated = "@example/trace-sdk", .recommend = "window.TraceClient(appfw 框架下，html 会默认注入 TraceClient 全局实例，无需安装额外依赖)" },
    .{ .deprecated = "moment", .recommend = "dayjs(原依赖包体积过大)" },
    .{ .deprecated = "lodash", .recommend = "appfw:stdlib/lodash 或 lodash-es" },
};

const profile_b_deps = [_]Dep{
    .{ .deprecated = "@example/bridge", .recommend = "appkit" },
    .{ .deprecated = "@example/request-adapter", .recommend = "@appfw/request/h5" },
    .{ .deprecated = "@example/legacy-util", .recommend = "@example/utils-next" },
    .{ .deprecated = "@example/legacy-util-mini", .recommend = "@example/utils-next" },
    .{ .deprecated = "@example/rpc-client", .recommend = "@appfw/request/h5" },
    .{ .deprecated = "@example/react-hooks", .recommend = "ahooks" },
    .{ .deprecated = "@example/state-store", .recommend = "appfw:stdlib/zustand" },
    .{ .deprecated = "@example/app-loader", .recommend = "appkit" },
    .{ .deprecated = "statekit", .recommend = "appfw:stdlib/zustand" },
    .{ .deprecated = "@example/mobile-ui", .recommend = "antd-mobile" },
    .{ .deprecated = "@example/legacy-ui", .recommend = "@example/ui" },
};

pub fn checkImportDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    index: ast.NodeIndex,
    profile: core.DeprecatedDependenceProfile,
) Allocator.Error!void {
    const source = importSource(tree, declaration) orelse return;
    const dep = deprecatedDependency(source, profile) orelse return;
    if (allSpecifiersWhitelisted(tree, declaration, dep.deprecated, profile)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "{s} 工具库不推荐使用，请使用 {s}",
        .{ dep.deprecated, dep.recommend },
    );
}

fn deprecatedDependency(source: []const u8, profile: core.DeprecatedDependenceProfile) ?Dep {
    if (findDeprecated(source, &default_deps)) |dep| return dep;

    switch (profile) {
        .default => return null,
        .profile_a => return findDeprecated(source, &profile_a_deps),
        .profile_b => return findDeprecated(source, &profile_b_deps),
    }
}

fn findDeprecated(source: []const u8, deps: []const Dep) ?Dep {
    for (deps) |dep| {
        if (std.mem.eql(u8, source, dep.deprecated)) return dep;
        if (std.mem.startsWith(u8, source, dep.deprecated) and
            source.len > dep.deprecated.len and
            source[dep.deprecated.len] == '/')
        {
            return dep;
        }
    }
    return null;
}

fn allSpecifiersWhitelisted(
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    deprecated_dep: []const u8,
    profile: core.DeprecatedDependenceProfile,
) bool {
    const specifiers = tree.extra(declaration.specifiers);
    if (specifiers.len == 0) return true;

    for (specifiers) |specifier_index| {
        const specifier = switch (tree.data(specifier_index)) {
            .import_specifier => |specifier| specifier,
            else => return false,
        };
        const name = importedName(tree, specifier.imported) orelse return false;
        if (!isWhitelisted(deprecated_dep, name, profile)) return false;
    }
    return true;
}

fn isWhitelisted(deprecated_dep: []const u8, imported: []const u8, profile: core.DeprecatedDependenceProfile) bool {
    return profile == .profile_a and
        std.mem.eql(u8, deprecated_dep, "@example/legacy-utils") and
        std.mem.eql(u8, imported, "AError");
}

fn importSource(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ?[]const u8 {
    return stringLiteralValue(tree, declaration.source);
}

fn importedName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}
