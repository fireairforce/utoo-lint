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

const JestGlobal = enum {
    expect,
    jest,
};

const ImportedGlobals = std.StringHashMapUnmanaged(JestGlobal);

const ObjectMatch = struct {
    canonical: []const u8,
    source: []const u8,
    scope: traverser.semantic.ScopeId,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
    jest_version: u32,
) Allocator.Error!void {
    var imported_globals: ImportedGlobals = .empty;
    defer imported_globals.deinit(allocator);
    try collectImportedGlobals(allocator, tree, &imported_globals);

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .scope_tree = scope_tree,
        .symbol_table = symbol_table,
        .imported_globals = &imported_globals,
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
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
    imported_globals: *const ImportedGlobals,
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

        const object = self.matchObject(ctx.tree, member.object) orelse return .proceed;
        const property_name = propertyName(ctx.tree, member) orelse return .proceed;
        const replacement = deprecationFor(self.jest_version, object.canonical, property_name) orelse return .proceed;
        const replacement_object = self.replacementObject(object, replacement.object);

        const message = try std.fmt.allocPrint(
            self.allocator,
            "`{s}.{s}` has been deprecated in favor of `{s}.{s}`",
            .{ object.source, property_name, replacement_object orelse replacement.object, replacement.property },
        );
        defer self.allocator.free(message);

        if (replacement_object == null) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                message,
                ctx.tree.span(index),
            );
            return .proceed;
        }

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
                .{ .span = ctx.tree.span(member.object), .replacement = replacement_object.? },
                .{ .span = ctx.tree.span(member.property), .replacement = property_replacement },
            },
        );
        return .proceed;
    }

    fn matchObject(self: *const Visitor, tree: *const ast.Tree, index: ast.NodeIndex) ?ObjectMatch {
        const object = unwrapTransparent(tree, index);
        const source_name = identifierName(tree, object) orelse return null;
        const reference_id = self.symbol_table.model.referenceOf(object) orelse return null;
        const reference = self.symbol_table.getReference(reference_id);
        const symbol_id = self.symbol_table.referenceSymbol(reference_id);

        if (symbol_id == .none) {
            if (!std.mem.eql(u8, source_name, "jest") and !std.mem.eql(u8, source_name, "require")) return null;
            return .{
                .canonical = source_name,
                .source = source_name,
                .scope = reference.scope,
            };
        }

        if (!self.isImportedGlobal(symbol_id, .jest)) return null;
        return .{
            .canonical = "jest",
            .source = source_name,
            .scope = reference.scope,
        };
    }

    fn replacementObject(self: *const Visitor, object: ObjectMatch, canonical: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, canonical, object.canonical)) return object.source;

        const global: JestGlobal = if (std.mem.eql(u8, canonical, "jest")) .jest else .expect;
        if (self.accessibleImportedName(object.scope, global)) |name| return name;
        if (self.hasImportedGlobal(global)) return null;
        if (self.symbol_table.resolve(self.scope_tree, object.scope, canonical) == null) return canonical;
        return null;
    }

    fn hasImportedGlobal(self: *const Visitor, expected: JestGlobal) bool {
        var iterator = self.imported_globals.valueIterator();
        while (iterator.next()) |global| {
            if (global.* == expected) return true;
        }
        return false;
    }

    fn accessibleImportedName(
        self: *const Visitor,
        scope: traverser.semantic.ScopeId,
        expected: JestGlobal,
    ) ?[]const u8 {
        var best: ?[]const u8 = null;
        var iterator = self.imported_globals.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.* != expected) continue;
            const symbol_id = self.symbol_table.resolve(self.scope_tree, scope, entry.key_ptr.*) orelse continue;
            if (!self.isImportedGlobal(symbol_id, expected)) continue;
            if (best == null or std.mem.order(u8, entry.key_ptr.*, best.?) == .lt) best = entry.key_ptr.*;
        }
        return best;
    }

    fn isImportedGlobal(self: *const Visitor, symbol_id: traverser.semantic.SymbolId, expected: JestGlobal) bool {
        const symbol = self.symbol_table.getSymbol(symbol_id);
        if (!symbol.flags.import) return false;
        return (self.imported_globals.get(self.symbol_table.tree.string(symbol.name)) orelse return false) == expected;
    }
};

fn collectImportedGlobals(
    allocator: Allocator,
    tree: *const ast.Tree,
    imported_globals: *ImportedGlobals,
) Allocator.Error!void {
    const program = switch (tree.data(tree.root)) {
        .program => |value| value,
        else => return,
    };

    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |value| value,
            else => continue,
        };
        if (declaration.import_kind == .type) continue;
        const source = stringLiteralValue(tree, declaration.source) orelse continue;
        if (!std.mem.eql(u8, source, "@jest/globals")) continue;

        for (tree.extra(declaration.specifiers)) |specifier_index| {
            const specifier = switch (tree.data(specifier_index)) {
                .import_specifier => |value| value,
                else => continue,
            };
            if (specifier.import_kind == .type) continue;
            const imported = propertyNodeName(tree, specifier.imported) orelse continue;
            const global: JestGlobal = if (std.mem.eql(u8, imported, "jest"))
                .jest
            else if (std.mem.eql(u8, imported, "expect"))
                .expect
            else
                continue;
            const local = bindingIdentifierName(tree, specifier.local) orelse continue;
            try imported_globals.put(allocator, local, global);
        }
    }
}

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

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn propertyNodeName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
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
