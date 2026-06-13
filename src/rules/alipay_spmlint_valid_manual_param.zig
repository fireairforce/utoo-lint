const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/spmLint/valid-manual-param";

const ParamType = enum {
    object,
    spm_id,
    expo_direction,

    fn name(self: ParamType) []const u8 {
        return switch (self) {
            .object => "object",
            .spm_id => "spmId",
            .expo_direction => "expoDirection",
        };
    }
};

const ParamCheck = union(enum) {
    pass,
    param_type,
    spm_id_click,
    spm_id_expo,
    expo_direction,
};

const log_pv_expected = [_]ParamType{.object};
const set_expected = [_]ParamType{.object};
const click_expected = [_]ParamType{ .spm_id, .object, .object, .object };
const expo_expected = [_]ParamType{ .spm_id, .expo_direction, .object, .object, .object };

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
) Allocator.Error!void {
    if (!isTracertCallNamed(tree, call, "call")) return;

    const args = tree.extra(call.arguments);
    if (args.len == 0) {
        try addRequireParam(allocator, diagnostics, tree, call, "call");
        return;
    }

    const fn_name = stringLiteralValue(tree, args[0]) orelse return;
    const expected_params = defaultParamsForFn(fn_name) orelse return;
    const params = args[1..];

    if (!std.mem.eql(u8, fn_name, "logPv") and params.len == 0) {
        try addRequireParam(allocator, diagnostics, tree, call, fn_name);
    }

    for (params, 0..) |arg, index| {
        const expected = if (index < expected_params.len) expected_params[index] else null;
        switch (checkParam(tree, arg, expected, fn_name)) {
            .pass => {},
            .spm_id_click => try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "点击埋点 spmId 格式应为 a.b.c.d、c.d",
                tree.span(arg),
            ),
            .spm_id_expo => try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "曝光埋点 spmId 格式应为 a.b.c?.d、c?.d",
                tree.span(arg),
            ),
            .expo_direction => try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                tree.span(arg),
                "函数 {s} 第 {d} 参数类型为字符串(曝光方向)",
                .{ fn_name, index + 1 },
            ),
            .param_type => {
                const expected_name = if (expected) |param_type| param_type.name() else "undefined";
                try core.addDiagnosticFmt(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    tree.span(arg),
                    "函数 {s} 第 {d} 参数类型为{s}",
                    .{ fn_name, index + 1, expected_name },
                );
            },
        }
    }
}

fn addRequireParam(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    fn_name: []const u8,
) Allocator.Error!void {
    const span = switch (tree.data(call.callee)) {
        .member_expression => |member| tree.span(member.property),
        else => tree.span(call.callee),
    };
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        span,
        "函数 {s} 需要传递参数",
        .{fn_name},
    );
}

fn defaultParamsForFn(fn_name: []const u8) ?[]const ParamType {
    if (std.mem.eql(u8, fn_name, "logPv")) return log_pv_expected[0..];
    if (std.mem.eql(u8, fn_name, "set")) return set_expected[0..];
    if (std.mem.eql(u8, fn_name, "click")) return click_expected[0..];
    if (std.mem.eql(u8, fn_name, "expo")) return expo_expected[0..];
    return null;
}

fn checkParam(tree: *const ast.Tree, index: ast.NodeIndex, expected: ?ParamType, fn_name: []const u8) ParamCheck {
    if (passesDynamicParam(tree, index)) return .pass;

    const param_type = expected orelse return .param_type;
    return switch (param_type) {
        .object => if (tree.data(index) == .object_expression) .pass else .param_type,
        .spm_id => checkSpmId(tree, index, fn_name),
        .expo_direction => checkExpoDirection(tree, index),
    };
}

fn checkSpmId(tree: *const ast.Tree, index: ast.NodeIndex, fn_name: []const u8) ParamCheck {
    switch (tree.data(index)) {
        .template_literal => return .pass,
        .string_literal => |literal| {
            const segments = countSegments(tree.string(literal.value));
            if (std.mem.eql(u8, fn_name, "expo")) {
                if (segments >= 1 and segments <= 4) return .pass;
                return .spm_id_expo;
            }
            if (std.mem.eql(u8, fn_name, "click")) {
                if (segments == 2 or segments == 4) return .pass;
                return .spm_id_click;
            }
            return .pass;
        },
        else => return .param_type,
    }
}

fn checkExpoDirection(tree: *const ast.Tree, index: ast.NodeIndex) ParamCheck {
    return switch (tree.data(index)) {
        .template_literal,
        .string_literal,
        .null_literal,
        => .pass,
        else => .expo_direction,
    };
}

fn countSegments(value: []const u8) usize {
    var count: usize = 1;
    for (value) |char| {
        if (char == '.') count += 1;
    }
    return count;
}

fn passesDynamicParam(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .call_expression,
        .conditional_expression,
        => true,
        .identifier_reference => |identifier| !std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        .member_expression => |member| identifierName(tree, member.property) != null,
        else => false,
    };
}

fn isTracertCallNamed(tree: *const ast.Tree, call: ast.CallExpression, name: []const u8) bool {
    const callee = switch (tree.data(call.callee)) {
        .member_expression => |member| member,
        else => return false,
    };

    const property = identifierName(tree, callee.property) orelse return false;
    return std.mem.eql(u8, property, name) and isTracertReceiver(tree, callee.object);
}

fn isTracertReceiver(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (isTracertIdentifier(tree, index)) return true;

    const member = switch (tree.data(index)) {
        .member_expression => |member| member,
        else => return false,
    };
    return isTracertIdentifier(tree, member.property);
}

fn isTracertIdentifier(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const name = identifierName(tree, index) orelse return false;
    return std.mem.eql(u8, name, "tracert") or
        std.mem.eql(u8, name, "Tracert") or
        std.mem.eql(u8, name, "$tracert");
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}
