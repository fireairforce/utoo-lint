const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-inner-declarations";

pub fn checkFunction(
    _: Allocator,
    _: *core.DiagnosticList,
    _: *const ast.Tree,
    _: ast.Function,
    _: ast.NodeIndex,
    _: *traverser.basic.Ctx,
) Allocator.Error!void {}
