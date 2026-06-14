const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "require-await";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,

    pub fn enter_function(
        self: *Visitor,
        function: ast.Function,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (function.async and !function.generator and !containsDirectAwait(ctx.tree, function.body)) {
            try self.addDiagnostic(ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_arrow_function_expression(
        self: *Visitor,
        function: ast.ArrowFunctionExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (function.async and !containsDirectAwait(ctx.tree, function.body)) {
            try self.addDiagnostic(ctx.tree, index);
        }
        return .proceed;
    }

    fn addDiagnostic(
        self: *Visitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
    ) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "Async function has no await expression.",
            tree.span(index),
        );
    }
};

const AwaitScanner = struct {
    found: bool = false,

    pub fn enter_await_expression(
        self: *AwaitScanner,
        _: ast.AwaitExpression,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        self.found = true;
        return .stop;
    }

    pub fn enter_function(
        _: *AwaitScanner,
        _: ast.Function,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        return .skip;
    }

    pub fn enter_arrow_function_expression(
        _: *AwaitScanner,
        _: ast.ArrowFunctionExpression,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        return .skip;
    }
};

fn containsDirectAwait(tree: *const ast.Tree, root: ast.NodeIndex) bool {
    if (root == .null) return false;

    var scanner = AwaitScanner{};
    var subtree = tree.*;
    subtree.root = root;
    traverser.basic.traverse(AwaitScanner, &subtree, &scanner) catch return false;
    return scanner.found;
}
