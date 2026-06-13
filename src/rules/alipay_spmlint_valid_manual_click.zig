const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/spmLint/valid-manual-click";

const expected_params = [_]ParamType{ .spm_id, .object, .object, .object };

const ParamType = enum {
    object,
    spm_id,

    fn name(self: ParamType) []const u8 {
        return switch (self) {
            .object => "object",
            .spm_id => "spmId",
        };
    }
};

const ParamCheck = union(enum) {
    pass,
    param_type,
    spm_id_click,
};

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
) Allocator.Error!void {
    if (!isTracertCallNamed(tree, call, "click")) return;

    const args = tree.extra(call.arguments);
    if (args.len == 0) {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "函数 click 需要传递参数",
            tree.span(call.callee),
        );
        return;
    }

    for (args, 0..) |arg, index| {
        const expected = if (index < expected_params.len) expected_params[index] else null;
        switch (checkParam(tree, arg, expected)) {
            .pass => {},
            .spm_id_click => try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "点击埋点 spmId 格式应为 a.b.c.d、c.d",
                tree.span(arg),
            ),
            .param_type => {
                const expected_name = if (expected) |param_type| param_type.name() else "undefined";
                try core.addDiagnosticFmt(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    tree.span(arg),
                    "函数 click 第 {d} 参数类型为{s}",
                    .{ index + 1, expected_name },
                );
            },
        }
    }
}

fn checkParam(tree: *const ast.Tree, index: ast.NodeIndex, expected: ?ParamType) ParamCheck {
    if (passesDynamicParam(tree, index)) return .pass;

    const param_type = expected orelse return .param_type;
    return switch (param_type) {
        .object => if (tree.data(index) == .object_expression) .pass else .param_type,
        .spm_id => checkSpmId(tree, index),
    };
}

fn checkSpmId(tree: *const ast.Tree, index: ast.NodeIndex) ParamCheck {
    switch (tree.data(index)) {
        .template_literal => return .pass,
        .string_literal => |literal| {
            const value = tree.string(literal.value);
            const segments = countSegments(value);
            if (segments == 2 or segments == 4) return .pass;
            return .spm_id_click;
        },
        else => return .param_type,
    }
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

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}
