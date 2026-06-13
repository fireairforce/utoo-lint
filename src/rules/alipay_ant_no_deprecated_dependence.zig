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
    .{ .deprecated = "@alipay/qiaozhi/utils", .recommend = "@alipay/shandie-utils" },
    .{ .deprecated = "@alipay/ivy-utils", .recommend = "@alipay/shandie-utils" },
    .{ .deprecated = "@alipay/qiaozhi/hooks", .recommend = "@alipay/shandie-hooks" },
    .{ .deprecated = "@alipay/ivy-hooks", .recommend = "@alipay/shandie-hooks" },
    .{ .deprecated = "@alipay/alipayjsapi", .recommend = "smallfish:jsapi" },
};

const ivy_deps = [_]Dep{
    .{ .deprecated = "@alipay/dp-anyshare-react", .recommend = "jsapi easyShare(原依赖包已不维护，体积也较大)" },
    .{ .deprecated = "@alipay/yuyan-monitor-web", .recommend = "window.yuyanMonitor(smallfish 框架下，html 会默认注入 yuyanMonitor 全局实例，无需安装额外依赖)" },
    .{ .deprecated = "@alipay/anylog", .recommend = "window.Tracert(原依赖包已不维护)" },
    .{ .deprecated = "@alipay/tracert", .recommend = "window.Tracert(smallfish 框架下，html 会默认注入 Tracert 全局实例，无需安装额外依赖)" },
    .{ .deprecated = "moment", .recommend = "dayjs(原依赖包体积过大)" },
    .{ .deprecated = "lodash", .recommend = "smallfish:stdlib/lodash 或 lodash-es" },
};

const insurance_deps = [_]Dep{
    .{ .deprecated = "@alipay/one-bridge", .recommend = "babyfish" },
    .{ .deprecated = "@alipay/insiop-comp-request", .recommend = "@smallfish:request/h5" },
    .{ .deprecated = "@alipay/bx-util", .recommend = "@alipay/bx-utils-next" },
    .{ .deprecated = "@alipay/bx-util-mp", .recommend = "@alipay/bx-utils-next" },
    .{ .deprecated = "@alipay/bx-rpc", .recommend = "@smallfish:request/h5" },
    .{ .deprecated = "@alipay/bx-react-hooks", .recommend = "ahooks" },
    .{ .deprecated = "@alipay/bx-store", .recommend = "smallfish:stdlib/zustand" },
    .{ .deprecated = "@alipay/bx-load", .recommend = "babyfish" },
    .{ .deprecated = "hooxjs", .recommend = "smallfish:stdlib/zustand" },
    .{ .deprecated = "@alipay/bx-mobile", .recommend = "antd-mobile" },
    .{ .deprecated = "@alipay/bx-bikini", .recommend = "@alipay/bikini" },
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
        .ivy => return findDeprecated(source, &ivy_deps),
        .insurance => return findDeprecated(source, &insurance_deps),
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
    return profile == .ivy and
        std.mem.eql(u8, deprecated_dep, "@alipay/qiaozhi/utils") and
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
