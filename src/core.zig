const std = @import("std");
const parser = @import("parser");

const ast = parser.ast;
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

pub const DiagnosticList = std.ArrayList(Diagnostic);

pub fn addDiagnostic(
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

pub fn addDiagnosticFmt(
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

pub fn freeDiagnostics(allocator: Allocator, diagnostics: *DiagnosticList) void {
    for (diagnostics.items) |diagnostic| {
        allocator.free(diagnostic.message);
    }
    diagnostics.deinit(allocator);
}

pub fn isKnownGlobal(name: []const u8) bool {
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

