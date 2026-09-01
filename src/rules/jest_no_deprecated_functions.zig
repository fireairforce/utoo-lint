const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "jest/no-deprecated-functions";
pub const latest_jest_version: u32 = 30;

const max_package_file_size = 1024 * 1024;

const Deprecation = struct {
    object: []const u8,
    property: []const u8,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    jest_version: u32,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .jest_version = if (jest_version == 0) latest_jest_version else jest_version,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

pub fn detectJestVersion(allocator: Allocator, io: std.Io, file_path: []const u8) Allocator.Error!?u32 {
    const absolute_file = if (std.fs.path.isAbsolute(file_path))
        try allocator.dupe(u8, file_path)
    else blk: {
        const cwd = std.process.currentPathAlloc(io, allocator) catch {
            break :blk try std.fs.path.resolve(allocator, &.{file_path});
        };
        defer allocator.free(cwd);
        break :blk try std.fs.path.resolve(allocator, &.{ cwd, file_path });
    };
    defer allocator.free(absolute_file);

    var current = try allocator.dupe(u8, std.fs.path.dirname(absolute_file) orelse ".");
    defer allocator.free(current);

    while (true) {
        const package_path = try std.fs.path.join(allocator, &.{ current, "node_modules", "jest", "package.json" });
        defer allocator.free(package_path);
        if (readJestVersion(allocator, io, package_path)) |version| return version;

        const parent = std.fs.path.dirname(current) orelse break;
        if (std.mem.eql(u8, parent, current)) break;
        const next = try allocator.dupe(u8, parent);
        allocator.free(current);
        current = next;
    }

    return null;
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    jest_version: u32,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const callee = unwrapTransparent(ctx.tree, call.callee);
        const member = switch (ctx.tree.data(callee)) {
            .member_expression => |value| value,
            else => return .proceed,
        };
        if (member.object == .null or member.property == .null) return .proceed;

        const object_name = identifierName(ctx.tree, member.object) orelse return .proceed;
        const property_name = propertyName(ctx.tree, member) orelse return .proceed;
        const replacement = deprecationFor(self.jest_version, object_name, property_name) orelse return .proceed;

        const message = try std.fmt.allocPrint(
            self.allocator,
            "`{s}.{s}` has been deprecated in favor of `{s}.{s}`",
            .{ object_name, property_name, replacement.object, replacement.property },
        );
        defer self.allocator.free(message);

        const property_replacement = if (member.computed)
            try std.fmt.allocPrint(self.allocator, "'{s}'", .{replacement.property})
        else
            replacement.property;
        defer if (member.computed) self.allocator.free(property_replacement);

        try core.addDiagnosticWithFixes(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            message,
            ctx.tree.span(index),
            &.{
                .{ .span = ctx.tree.span(member.object), .replacement = replacement.object },
                .{ .span = ctx.tree.span(member.property), .replacement = property_replacement },
            },
        );
        return .proceed;
    }
};

fn deprecationFor(version: u32, object: []const u8, property: []const u8) ?Deprecation {
    if (version >= 15 and std.mem.eql(u8, object, "jest") and std.mem.eql(u8, property, "resetModuleRegistry")) {
        return .{ .object = "jest", .property = "resetModules" };
    }
    if (version >= 17 and std.mem.eql(u8, object, "jest") and std.mem.eql(u8, property, "addMatchers")) {
        return .{ .object = "expect", .property = "extend" };
    }
    if (version >= 21 and std.mem.eql(u8, object, "require") and std.mem.eql(u8, property, "requireMock")) {
        return .{ .object = "jest", .property = "requireMock" };
    }
    if (version >= 21 and std.mem.eql(u8, object, "require") and std.mem.eql(u8, property, "requireActual")) {
        return .{ .object = "jest", .property = "requireActual" };
    }
    if (version >= 22 and std.mem.eql(u8, object, "jest") and std.mem.eql(u8, property, "runTimersToTime")) {
        return .{ .object = "jest", .property = "advanceTimersByTime" };
    }
    if (version >= 26 and std.mem.eql(u8, object, "jest") and std.mem.eql(u8, property, "genMockFromModule")) {
        return .{ .object = "jest", .property = "createMockFromModule" };
    }
    return null;
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    return if (member.computed)
        switch (tree.data(member.property)) {
            .string_literal => |literal| tree.string(literal.value),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }
    return current;
}

fn readJestVersion(allocator: Allocator, io: std.Io, path: []const u8) ?u32 {
    const directory_path = std.fs.path.dirname(path) orelse return null;
    const basename = std.fs.path.basename(path);
    var directory = std.Io.Dir.openDirAbsolute(io, directory_path, .{}) catch return null;
    defer directory.close(io);
    const source = directory.readFileAlloc(io, basename, allocator, .limited(max_package_file_size)) catch return null;
    defer allocator.free(source);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{}) catch return null;
    defer parsed.deinit();
    const root = switch (parsed.value) {
        .object => |object| object,
        else => return null,
    };
    const version = switch (root.get("version") orelse return null) {
        .string => |value| value,
        else => return null,
    };
    const separator = std.mem.indexOfScalar(u8, version, '.') orelse version.len;
    if (separator == 0) return null;
    return std.fmt.parseUnsigned(u32, version[0..separator], 10) catch null;
}
