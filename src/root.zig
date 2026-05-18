const std = @import("std");
const parser = @import("parser");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const Severity = enum {
    @"error",
    warning,

    pub fn toString(self: Severity) []const u8 {
        return switch (self) {
            .@"error" => "error",
            .warning => "warning",
        };
    }
};

pub const Options = struct {
    no_console: bool = true,
    no_debugger: bool = true,
    no_var: bool = true,
    eqeqeq: bool = true,
    no_unused_vars: bool = true,
    no_undef: bool = true,
    parser_semantic_errors: bool = true,
};

pub const Diagnostic = struct {
    rule_id: []const u8,
    message: []const u8,
    span: ast.Span,
    severity: Severity,
};

pub const Result = struct {
    diagnostics: []Diagnostic,

    pub fn deinit(self: *Result, allocator: Allocator) void {
        for (self.diagnostics) |diagnostic| {
            allocator.free(diagnostic.message);
        }
        allocator.free(self.diagnostics);
    }

    pub fn hasDiagnostics(self: Result) bool {
        return self.diagnostics.len > 0;
    }

    pub fn hasErrors(self: Result) bool {
        for (self.diagnostics) |diagnostic| {
            if (diagnostic.severity == .@"error") return true;
        }
        return false;
    }
};

pub const SourcePosition = struct {
    line: usize,
    column: usize,
};

const DiagnosticList = std.ArrayList(Diagnostic);

pub fn lintSource(
    allocator: Allocator,
    source: []const u8,
    path: []const u8,
    options: Options,
) Allocator.Error!Result {
    var diagnostics: DiagnosticList = .empty;
    errdefer freeDiagnostics(allocator, &diagnostics);

    var tree = try parser.parse(allocator, source, .{
        .source_type = ast.SourceType.fromPath(path),
        .lang = ast.Lang.fromPath(path),
    });
    defer tree.deinit();

    const needs_semantic = options.parser_semantic_errors or options.no_unused_vars or options.no_undef;

    if (needs_semantic) {
        var semantic_result = try parser.semantic.analyze(&tree);
        try semantic_result.symbol_table.resolveAll(semantic_result.scope_tree);
        try appendParserDiagnostics(allocator, &diagnostics, &tree);
        try runBasicRules(allocator, &diagnostics, &tree, options);
        try runSemanticRules(allocator, &diagnostics, &tree, semantic_result, options);
    } else {
        try appendParserDiagnostics(allocator, &diagnostics, &tree);
        try runBasicRules(allocator, &diagnostics, &tree, options);
    }

    return .{
        .diagnostics = try diagnostics.toOwnedSlice(allocator),
    };
}

pub fn isLintablePath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".js") or
        std.mem.endsWith(u8, path, ".jsx") or
        std.mem.endsWith(u8, path, ".ts") or
        std.mem.endsWith(u8, path, ".tsx") or
        std.mem.endsWith(u8, path, ".mjs") or
        std.mem.endsWith(u8, path, ".cjs") or
        std.mem.endsWith(u8, path, ".mts") or
        std.mem.endsWith(u8, path, ".cts");
}

pub fn offsetToLineColumn(source: []const u8, offset: u32) SourcePosition {
    const offset_usize: usize = @intCast(offset);
    const end = @min(offset_usize, source.len);
    var line: usize = 1;
    var column: usize = 1;
    var index: usize = 0;

    while (index < end) : (index += 1) {
        if (source[index] == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }
    }

    return .{ .line = line, .column = column };
}

fn runBasicRules(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    tree: *const ast.Tree,
    options: Options,
) Allocator.Error!void {
    var visitor = BasicRuleVisitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .options = options,
    };

    try traverser.basic.traverse(BasicRuleVisitor, tree, &visitor);
}

fn runSemanticRules(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    tree: *const ast.Tree,
    semantic_result: traverser.semantic.Result,
    options: Options,
) Allocator.Error!void {
    if (options.no_unused_vars) {
        try reportUnusedSymbols(allocator, diagnostics, tree, semantic_result.symbol_table);
    }

    if (options.no_undef) {
        try reportUndefinedReferences(allocator, diagnostics, tree, semantic_result.symbol_table);
    }
}

const BasicRuleVisitor = struct {
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    options: Options,

    pub fn enter_debugger_statement(
        self: *BasicRuleVisitor,
        _: ast.DebuggerStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_debugger) {
            try addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                "no-debugger",
                "Unexpected debugger statement.",
                ctx.tree.span(index),
            );
        }
        return .proceed;
    }

    pub fn enter_variable_declaration(
        self: *BasicRuleVisitor,
        declaration: ast.VariableDeclaration,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_var and declaration.kind == .@"var") {
            try addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                "no-var",
                "Use 'let' or 'const' instead of 'var'.",
                ctx.tree.span(index),
            );
        }
        return .proceed;
    }

    pub fn enter_binary_expression(
        self: *BasicRuleVisitor,
        expression: ast.BinaryExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.eqeqeq and (expression.operator == .equal or expression.operator == .not_equal)) {
            try addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                "eqeqeq",
                "Use strict equality operators.",
                ctx.tree.span(index),
            );
        }
        return .proceed;
    }

    pub fn enter_call_expression(
        self: *BasicRuleVisitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.options.no_console and isConsoleMemberCall(ctx.tree, call.callee)) {
            try addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                "no-console",
                "Unexpected console call.",
                ctx.tree.span(index),
            );
        }
        return .proceed;
    }
};

fn reportUnusedSymbols(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var iter = symbol_table.iterSymbols();

    while (iter.next()) |entry| {
        const symbol = entry.symbol;
        const flags = symbol.flags;

        if (!isLintableSymbol(flags)) continue;
        if (flags.exported or flags.ambient) continue;
        if (flags.parameter or flags.catch_var) continue;
        if (symbol_table.isReferenced(entry.id)) continue;

        const name = tree.string(symbol.name);
        if (std.mem.startsWith(u8, name, "_")) continue;

        const decls = symbol_table.symbolDecls(entry.id);
        if (decls.len == 0) continue;

        try addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            "no-unused-vars",
            tree.span(decls[0]),
            "'{s}' is declared but never used.",
            .{name},
        );
    }
}

fn reportUndefinedReferences(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var iter = symbol_table.iterUnresolved();

    while (iter.next()) |entry| {
        const reference = entry.reference;
        if (reference.kind != .value) continue;

        const name = tree.string(reference.name);
        if (isKnownGlobal(name)) continue;

        try addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            "no-undef",
            tree.span(reference.node),
            "'{s}' is not defined.",
            .{name},
        );
    }
}

fn isLintableSymbol(flags: traverser.semantic.Symbol.Flags) bool {
    return flags.inValueSpace() or
        flags.import or
        flags.type_import or
        flags.interface or
        flags.type_alias;
}

fn isConsoleMemberCall(tree: *const ast.Tree, callee: ast.NodeIndex) bool {
    var current = callee;

    switch (tree.data(current)) {
        .chain_expression => |chain| current = chain.expression,
        else => {},
    }

    return switch (tree.data(current)) {
        .member_expression => |member| isIdentifierNamed(tree, member.object, "console"),
        else => false,
    };
}

fn isIdentifierNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn isKnownGlobal(name: []const u8) bool {
    const globals = [_][]const u8{
        "Array",
        "BigInt",
        "Boolean",
        "Buffer",
        "Date",
        "Error",
        "Headers",
        "Infinity",
        "Intl",
        "JSON",
        "Map",
        "Math",
        "NaN",
        "Number",
        "Object",
        "Promise",
        "RegExp",
        "Request",
        "Response",
        "Set",
        "String",
        "Symbol",
        "URL",
        "URLSearchParams",
        "WeakMap",
        "WeakSet",
        "__dirname",
        "__filename",
        "clearInterval",
        "clearTimeout",
        "console",
        "document",
        "exports",
        "fetch",
        "global",
        "globalThis",
        "module",
        "process",
        "queueMicrotask",
        "require",
        "setInterval",
        "setTimeout",
        "undefined",
        "window",
    };

    for (globals) |global| {
        if (std.mem.eql(u8, name, global)) return true;
    }

    return false;
}

fn appendParserDiagnostics(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    for (tree.diagnostics.items) |diagnostic| {
        try addDiagnostic(
            allocator,
            diagnostics,
            if (diagnostic.severity == .@"error") .@"error" else .warning,
            "parse",
            diagnostic.message,
            diagnostic.span,
        );
    }
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    severity: Severity,
    rule_id: []const u8,
    message: []const u8,
    span: ast.Span,
) Allocator.Error!void {
    const owned_message = try allocator.dupe(u8, message);
    errdefer allocator.free(owned_message);

    try diagnostics.append(allocator, .{
        .rule_id = rule_id,
        .message = owned_message,
        .span = span,
        .severity = severity,
    });
}

fn addDiagnosticFmt(
    allocator: Allocator,
    diagnostics: *DiagnosticList,
    severity: Severity,
    rule_id: []const u8,
    span: ast.Span,
    comptime fmt: []const u8,
    args: anytype,
) Allocator.Error!void {
    const owned_message = try std.fmt.allocPrint(allocator, fmt, args);
    errdefer allocator.free(owned_message);

    try diagnostics.append(allocator, .{
        .rule_id = rule_id,
        .message = owned_message,
        .span = span,
        .severity = severity,
    });
}

fn freeDiagnostics(allocator: Allocator, diagnostics: *DiagnosticList) void {
    for (diagnostics.items) |diagnostic| {
        allocator.free(diagnostic.message);
    }
    diagnostics.deinit(allocator);
}

fn hasRule(result: Result, rule_id: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return true;
    }
    return false;
}

test "reports structural rules" {
    const source =
        \\var value = 1;
        \\if (value == 1) {
        \\  console.log(value);
        \\  debugger;
        \\}
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(hasRule(result, "no-var"));
    try std.testing.expect(hasRule(result, "eqeqeq"));
    try std.testing.expect(hasRule(result, "no-console"));
    try std.testing.expect(hasRule(result, "no-debugger"));
}

test "reports semantic rules" {
    const source =
        \\const unused = missing;
        \\const used = 1;
        \\console.log(used);
    ;

    var result = try lintSource(std.testing.allocator, source, "fixture.ts", .{});
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(hasRule(result, "no-unused-vars"));
    try std.testing.expect(hasRule(result, "no-undef"));
}
