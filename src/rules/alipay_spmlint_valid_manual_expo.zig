const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/spmLint/valid-manual-expo";

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
    spm_id_expo,
    expo_direction,
};

const TracertName = enum {
    tracert,
    Tracert,
    dollar_tracert,
};

const lowercase_expected = [_]ParamType{ .spm_id, .object, .object, .object };
const uppercase_expected = [_]ParamType{ .spm_id, .expo_direction, .object, .object, .object };

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
) Allocator.Error!void {
    const tracert_name = tracertCallName(tree, call, "expo") orelse return;
    const expected_params = if (tracert_name == .Tracert) uppercase_expected[0..] else lowercase_expected[0..];

    const args = tree.extra(call.arguments);
    if (args.len == 0) {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "函数 expo 需要传递参数",
            tree.span(call.callee),
        );
        return;
    }

    for (args, 0..) |arg, index| {
        const expected = if (index < expected_params.len) expected_params[index] else null;
        switch (checkParam(tree, arg, expected)) {
            .pass => {},
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
                "函数 expo 第 {d} 参数类型为字符串(曝光方向)",
                .{index + 1},
            ),
            .param_type => {
                const expected_name = if (expected) |param_type| param_type.name() else "undefined";
                try core.addDiagnosticFmt(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    tree.span(arg),
                    "函数 expo 第 {d} 参数类型为{s}",
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
        .expo_direction => checkExpoDirection(tree, index),
    };
}

fn checkSpmId(tree: *const ast.Tree, index: ast.NodeIndex) ParamCheck {
    switch (tree.data(index)) {
        .template_literal => return .pass,
        .string_literal => |literal| {
            const segments = countSegments(tree.string(literal.value));
            if (segments >= 1 and segments <= 4) return .pass;
            return .spm_id_expo;
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

fn tracertCallName(tree: *const ast.Tree, call: ast.CallExpression, name: []const u8) ?TracertName {
    const callee = switch (tree.data(call.callee)) {
        .member_expression => |member| member,
        else => return null,
    };

    const property = identifierName(tree, callee.property) orelse return null;
    if (!std.mem.eql(u8, property, name)) return null;
    return tracertReceiverName(tree, callee.object);
}

fn tracertReceiverName(tree: *const ast.Tree, index: ast.NodeIndex) ?TracertName {
    if (tracertIdentifierName(tree, index)) |name| return name;

    const member = switch (tree.data(index)) {
        .member_expression => |member| member,
        else => return null,
    };
    return tracertIdentifierName(tree, member.property);
}

fn tracertIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?TracertName {
    const name = identifierName(tree, index) orelse return null;
    if (std.mem.eql(u8, name, "tracert")) return .tracert;
    if (std.mem.eql(u8, name, "Tracert")) return .Tracert;
    if (std.mem.eql(u8, name, "$tracert")) return .dollar_tracert;
    return null;
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}
