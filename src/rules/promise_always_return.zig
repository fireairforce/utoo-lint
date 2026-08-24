const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "promise/always-return";

pub const Options = struct {
    ignore_last_callback: bool = false,
    ignore_assignment_variables: core.PromiseAlwaysReturnIgnoreAssignmentVariables = .{},
};

const Completion = enum {
    continues,
    terminal,
    non_terminal_exit,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    const callback = inlineThenCallback(tree, call) orelse return;
    const last_callback = isLastCallback(tree, index, ctx);

    if (options.ignore_last_callback and last_callback) return;
    if (last_callback and hasIgnoredAssignment(tree, callback, &options.ignore_assignment_variables)) return;
    if (callbackIsTerminal(tree, callback)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Each then() should return a value or throw",
        tree.span(callback),
    );
}

fn inlineThenCallback(tree: *const ast.Tree, call: ast.CallExpression) ?ast.NodeIndex {
    const callee = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return null,
    };
    if (!isNonComputedPropertyNamed(tree, callee, "then")) return null;

    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return null;
    const callback = unwrapTransparent(tree, arguments[0]);
    return switch (tree.data(callback)) {
        .function => callback,
        .arrow_function_expression => |arrow| if (arrow.expression) null else callback,
        else => null,
    };
}

fn callbackIsTerminal(tree: *const ast.Tree, callback: ast.NodeIndex) bool {
    const body_index = switch (tree.data(callback)) {
        .function => |function| function.body,
        .arrow_function_expression => |arrow| arrow.body,
        else => return true,
    };
    if (body_index == .null) return true;

    const body = switch (tree.data(body_index)) {
        .function_body => |function_body| function_body,
        else => return true,
    };
    return rangeCompletion(tree, body.body) == .terminal;
}

fn rangeCompletion(tree: *const ast.Tree, range: ast.IndexRange) Completion {
    for (tree.extra(range)) |statement| {
        const completion = statementCompletion(tree, statement);
        if (completion != .continues) return completion;
    }
    return .continues;
}

fn statementCompletion(tree: *const ast.Tree, index: ast.NodeIndex) Completion {
    if (index == .null) return .continues;

    return switch (tree.data(index)) {
        .return_statement,
        .throw_statement,
        => .terminal,
        .break_statement,
        .continue_statement,
        => .non_terminal_exit,
        .expression_statement => |statement| if (isProcessTerminationCall(tree, statement.expression)) .terminal else .continues,
        .block_statement => |block| rangeCompletion(tree, block.body),
        .if_statement => |statement| ifCompletion(tree, statement),
        .try_statement => |statement| tryCompletion(tree, statement),
        .switch_statement => |statement| switchCompletion(tree, statement),
        else => .continues,
    };
}

fn ifCompletion(tree: *const ast.Tree, statement: ast.IfStatement) Completion {
    if (statement.alternate == .null) return .continues;
    const consequent = statementCompletion(tree, statement.consequent);
    const alternate = statementCompletion(tree, statement.alternate);
    if (consequent == .terminal and alternate == .terminal) return .terminal;
    if (consequent != .continues and alternate != .continues) return .non_terminal_exit;
    return .continues;
}

fn tryCompletion(tree: *const ast.Tree, statement: ast.TryStatement) Completion {
    if (statement.finalizer != .null and statementCompletion(tree, statement.finalizer) == .terminal) {
        return .terminal;
    }

    if (statementCompletion(tree, statement.block) != .terminal) return .continues;
    if (statement.handler == .null) return .terminal;

    const handler_body = switch (tree.data(statement.handler)) {
        .catch_clause => |handler| handler.body,
        else => return .continues,
    };
    return statementCompletion(tree, handler_body);
}

fn switchCompletion(tree: *const ast.Tree, statement: ast.SwitchStatement) Completion {
    const cases = tree.extra(statement.cases);
    if (cases.len == 0) return .continues;

    var has_default = false;
    var following_terminal = false;
    var all_terminal = true;
    var offset = cases.len;
    while (offset > 0) {
        offset -= 1;
        const switch_case = switch (tree.data(cases[offset])) {
            .switch_case => |case| case,
            else => return .continues,
        };
        if (switch_case.@"test" == .null) has_default = true;

        const completion = rangeCompletion(tree, switch_case.consequent);
        const current_terminal = completion == .terminal or (completion == .continues and following_terminal);
        if (!current_terminal) all_terminal = false;
        following_terminal = current_terminal;
    }

    return if (has_default and all_terminal) .terminal else .continues;
}

fn isProcessTerminationCall(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const call = switch (tree.data(unwrapTransparent(tree, index))) {
        .call_expression => |call| call,
        else => return false,
    };
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (!isIdentifierReferenceNamed(tree, member.object, "process")) return false;
    return isNonComputedPropertyNamed(tree, member, "exit") or
        isNonComputedPropertyNamed(tree, member, "abort");
}

fn isLastCallback(
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) bool {
    var target = index;
    var depth: usize = 1;

    while (ctx.path.ancestor(depth)) |parent_index| {
        switch (tree.data(parent_index)) {
            .expression_statement => |statement| return statement.expression == target,
            .unary_expression => |expression| return expression.argument == target and expression.operator == .void,
            .sequence_expression => |sequence| {
                const expressions = tree.extra(sequence.expressions);
                if (expressions.len == 0) return false;
                if (expressions[expressions.len - 1] != target) return true;
                target = parent_index;
                depth += 1;
            },
            .chain_expression => |chain| {
                if (chain.expression != target) return false;
                target = parent_index;
                depth += 1;
            },
            .parenthesized_expression => |parenthesized| {
                if (parenthesized.expression != target) return false;
                target = parent_index;
                depth += 1;
            },
            .await_expression => |expression| {
                if (expression.argument != target) return false;
                target = parent_index;
                depth += 1;
            },
            .member_expression => |member| {
                if (member.object != target) return false;
                const outer_call_index = ctx.path.ancestor(depth + 1) orelse return false;
                const outer_call = switch (tree.data(outer_call_index)) {
                    .call_expression => |call| call,
                    else => return false,
                };
                if (unwrapTransparent(tree, outer_call.callee) != parent_index) return false;
                if (!isNonComputedPropertyNamed(tree, member, "catch") and
                    !isNonComputedPropertyNamed(tree, member, "finally")) return false;
                target = outer_call_index;
                depth += 2;
            },
            else => return false,
        }
    }

    return false;
}

fn hasIgnoredAssignment(
    tree: *const ast.Tree,
    callback: ast.NodeIndex,
    ignored: *const core.PromiseAlwaysReturnIgnoreAssignmentVariables,
) bool {
    const body_index = switch (tree.data(callback)) {
        .function => |function| function.body,
        .arrow_function_expression => |arrow| arrow.body,
        else => return false,
    };
    const body = switch (tree.data(body_index)) {
        .function_body => |function_body| function_body,
        else => return false,
    };

    for (tree.extra(body.body)) |statement_index| {
        const expression_index = switch (tree.data(statement_index)) {
            .expression_statement => |statement| statement.expression,
            else => continue,
        };
        const assignment = switch (tree.data(unwrapTransparent(tree, expression_index))) {
            .assignment_expression => |assignment| assignment,
            else => continue,
        };
        const root_name = rootObjectName(tree, assignment.left) orelse continue;
        if (ignored.contains(root_name)) return true;
    }
    return false;
}

fn rootObjectName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .member_expression => |member| rootObjectName(tree, member.object),
        else => null,
    };
}

fn isNonComputedPropertyNamed(tree: *const ast.Tree, member: ast.MemberExpression, name: []const u8) bool {
    if (member.computed or member.property == .null) return false;
    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
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
