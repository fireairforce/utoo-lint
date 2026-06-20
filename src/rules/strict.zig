const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "strict";

pub const Mode = enum {
    safe,
    global,
    function,
    never,
};

pub fn runWithMode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    mode: Mode,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .mode = if (tree.isModule()) .module else switch (mode) {
            .safe => .function,
            .global => .global,
            .function => .function,
            .never => .never,
        },
        .scope_stack = std.ArrayList(bool).empty,
    };
    defer visitor.scope_stack.deinit(allocator);

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const EffectiveMode = enum {
    module,
    global,
    function,
    never,
};

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    mode: EffectiveMode,
    scope_stack: std.ArrayList(bool),
    class_depth: usize = 0,

    pub fn enter_program(
        self: *Visitor,
        program: ast.Program,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const body = ctx.tree.extra(program.body);
        switch (self.mode) {
            .global => {
                if (body.len > 0 and useStrictCount(ctx.tree, program.body) == 0) {
                    try addDiagnostic(self.allocator, self.diagnostics, ctx.tree, index, "Use the global form of 'use strict'.");
                }
                try reportDuplicateDirectives(self.allocator, self.diagnostics, ctx.tree, program.body);
            },
            .function => {},
            .never => try reportDirectives(self.allocator, self.diagnostics, ctx.tree, program.body, "Strict mode is not permitted."),
            .module => try reportDirectives(self.allocator, self.diagnostics, ctx.tree, program.body, "'use strict' is unnecessary inside of modules."),
        }
        return .proceed;
    }

    pub fn enter_function(
        self: *Visitor,
        function: ast.Function,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const body_range = functionBodyRange(ctx.tree, function.body);
        const count = if (body_range) |range| useStrictCount(ctx.tree, range) else 0;

        if (self.mode == .function) {
            try self.enterFunctionInFunctionMode(ctx.tree, function, index, body_range, count);
        } else if (count > 0) {
            const first_directive = firstUseStrictDirective(ctx.tree, body_range.?).?;
            if (!isSimpleParameterList(ctx.tree, function.params)) {
                try addDiagnostic(
                    self.allocator,
                    self.diagnostics,
                    ctx.tree,
                    first_directive,
                    "'use strict' directive inside a function with non-simple parameter list throws a syntax error since ES2016.",
                );
                try reportDuplicateDirectives(self.allocator, self.diagnostics, ctx.tree, body_range.?);
            } else {
                const message = switch (self.mode) {
                    .global => "Use the global form of 'use strict'.",
                    .never => "Strict mode is not permitted.",
                    .module => "'use strict' is unnecessary inside of modules.",
                    .function => unreachable,
                };
                try reportDirectives(self.allocator, self.diagnostics, ctx.tree, body_range.?, message);
            }
        }

        return .proceed;
    }

    pub fn exit_function(self: *Visitor, _: ast.Function, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        if (self.mode == .function and self.scope_stack.items.len > 0) {
            _ = self.scope_stack.pop();
        }
    }

    pub fn enter_class(self: *Visitor, _: ast.Class, _: ast.NodeIndex, _: *traverser.basic.Ctx) traverser.Action {
        self.class_depth += 1;
        return .proceed;
    }

    pub fn exit_class(self: *Visitor, _: ast.Class, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.class_depth -= 1;
    }

    fn enterFunctionInFunctionMode(
        self: *Visitor,
        tree: *const ast.Tree,
        function: ast.Function,
        index: ast.NodeIndex,
        body_range: ?ast.IndexRange,
        use_strict_count: usize,
    ) Allocator.Error!void {
        const parent_is_global = self.scope_stack.items.len == 0 and self.class_depth == 0;
        const parent_is_strict = self.scope_stack.items.len > 0 and self.scope_stack.items[self.scope_stack.items.len - 1];
        const function_is_strict = use_strict_count > 0;

        if (function_is_strict) {
            const first_directive = firstUseStrictDirective(tree, body_range.?).?;
            if (!isSimpleParameterList(tree, function.params)) {
                try addDiagnostic(
                    self.allocator,
                    self.diagnostics,
                    tree,
                    first_directive,
                    "'use strict' directive inside a function with non-simple parameter list throws a syntax error since ES2016.",
                );
            } else if (parent_is_strict) {
                try addDiagnostic(self.allocator, self.diagnostics, tree, first_directive, "Unnecessary 'use strict' directive.");
            } else if (self.class_depth > 0) {
                try addDiagnostic(self.allocator, self.diagnostics, tree, first_directive, "'use strict' is unnecessary inside of classes.");
            }
            try reportDuplicateDirectives(self.allocator, self.diagnostics, tree, body_range.?);
        } else if (parent_is_global and isSimpleParameterList(tree, function.params)) {
            try addDiagnostic(self.allocator, self.diagnostics, tree, index, "Use the function form of 'use strict'.");
        }

        try self.scope_stack.append(self.allocator, parent_is_strict or function_is_strict);
    }
};

fn functionBodyRange(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.IndexRange {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .function_body => |body| body.body,
        else => null,
    };
}

fn useStrictCount(tree: *const ast.Tree, body: ast.IndexRange) usize {
    var count: usize = 0;
    for (tree.extra(body)) |statement| {
        if (isUseStrictDirective(tree, statement)) {
            count += 1;
        } else {
            break;
        }
    }
    return count;
}

fn firstUseStrictDirective(tree: *const ast.Tree, body: ast.IndexRange) ?ast.NodeIndex {
    for (tree.extra(body)) |statement| {
        if (isUseStrictDirective(tree, statement)) return statement;
        break;
    }
    return null;
}

fn reportDirectives(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.IndexRange,
    message: []const u8,
) Allocator.Error!void {
    for (tree.extra(body)) |statement| {
        if (!isUseStrictDirective(tree, statement)) break;
        try addDiagnostic(allocator, diagnostics, tree, statement, message);
    }
}

fn reportDuplicateDirectives(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.IndexRange,
) Allocator.Error!void {
    var seen_first = false;
    for (tree.extra(body)) |statement| {
        if (!isUseStrictDirective(tree, statement)) break;
        if (seen_first) {
            try addDiagnostic(allocator, diagnostics, tree, statement, "Multiple 'use strict' directives.");
        } else {
            seen_first = true;
        }
    }
}

fn isUseStrictDirective(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .directive => |directive| std.mem.eql(u8, tree.string(directive.value), "use strict"),
        else => false,
    };
}

fn isSimpleParameterList(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return true;
    const params = switch (tree.data(index)) {
        .formal_parameters => |params| params,
        else => return true,
    };

    for (tree.extra(params.items)) |item| {
        const parameter = switch (tree.data(item)) {
            .formal_parameter => |parameter| parameter,
            else => return false,
        };
        if (tree.data(parameter.pattern) != .binding_identifier) return false;
    }
    return params.rest == .null;
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    message: []const u8,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        tree.span(index),
    );
}
