const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-unexpected-multiline";

const function_message = "Unexpected newline between function and ( of function call.";
const property_message = "Unexpected newline between object and [ of property access.";
const tagged_template_message = "Unexpected newline between template tag and template literal.";
const division_message = "Unexpected newline between numerator and division operator.";

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
) Allocator.Error!void {
    if (call.optional or call.arguments.len == 0) return;

    const boundary = if (call.type_arguments != .null)
        tree.span(call.type_arguments).end
    else
        tree.span(call.callee).end;
    const call_end = tree.span(tree.extra(call.arguments)[0]).start;
    const open_paren = findDelimiterOutsideComments(tree.source, boundary, call_end +| 1, '(') orelse return;
    if (!containsLinebreak(tree.source, boundary, open_paren)) return;

    try report(allocator, diagnostics, open_paren, function_message);
}

pub fn checkMemberExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
) Allocator.Error!void {
    if (!member.computed or member.optional) return;

    const boundary = tree.span(member.object).end;
    const property_start = tree.span(member.property).start;
    const open_bracket = findDelimiterOutsideComments(tree.source, boundary, property_start +| 1, '[') orelse return;
    if (!containsLinebreak(tree.source, boundary, open_bracket)) return;

    try report(allocator, diagnostics, open_bracket, property_message);
}

pub fn checkTaggedTemplateExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    tagged: ast.TaggedTemplateExpression,
) Allocator.Error!void {
    const boundary = if (tagged.type_arguments != .null)
        tree.span(tagged.type_arguments).end
    else
        tree.span(tagged.tag).end;
    const quasi_start = tree.span(tagged.quasi).start;
    if (!containsLinebreak(tree.source, boundary, quasi_start)) return;

    try report(allocator, diagnostics, quasi_start, tagged_template_message);
}

pub fn checkBinaryExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
) Allocator.Error!void {
    if (expression.operator != .divide) return;

    const left_binary = switch (tree.data(expression.left)) {
        .binary_expression => |binary| binary,
        else => return,
    };
    if (left_binary.operator != .divide) return;

    const right_start: usize = @intCast(tree.span(expression.right).start);
    if (right_start == 0 or right_start > tree.source.len or tree.source[right_start - 1] != '/') return;
    if (!startsWithRegexFlagsIdentifier(tree.source, right_start)) return;

    const numerator_end = tree.span(left_binary.left).end;
    const denominator_start = tree.span(left_binary.right).start;
    const first_slash = findDelimiterOutsideComments(tree.source, numerator_end, denominator_start, '/') orelse return;
    if (!containsLinebreak(tree.source, numerator_end, first_slash)) return;

    try report(allocator, diagnostics, first_slash, division_message);
}

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    offset: u32,
    message: []const u8,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        .{ .start = offset, .end = offset + 1 },
    );
}

fn containsLinebreak(source: []const u8, start: u32, end: u32) bool {
    if (start >= end or end > source.len) return false;
    return std.mem.indexOfAny(u8, source[start..end], "\r\n") != null;
}

fn findDelimiterOutsideComments(source: []const u8, start: u32, end: u32, delimiter: u8) ?u32 {
    var index: usize = @intCast(start);
    const limit = @min(@as(usize, @intCast(end)), source.len);

    while (index < limit) {
        if (source[index] == '/' and index + 1 < limit) {
            if (source[index + 1] == '/') {
                index += 2;
                while (index < limit and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
                continue;
            }
            if (source[index + 1] == '*') {
                index += 2;
                while (index + 1 < limit and !(source[index] == '*' and source[index + 1] == '/')) : (index += 1) {}
                index = @min(index + 2, limit);
                continue;
            }
        }

        if (source[index] == delimiter) return @intCast(index);
        index += 1;
    }

    return null;
}

fn startsWithRegexFlagsIdentifier(source: []const u8, start: usize) bool {
    if (start >= source.len or !isIdentifierByte(source[start])) return false;

    var index = start;
    while (index < source.len and isIdentifierByte(source[index])) : (index += 1) {
        switch (source[index]) {
            'g', 'i', 'm', 's', 'u', 'y' => {},
            else => return false,
        }
    }
    return index > start;
}

fn isIdentifierByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$';
}
