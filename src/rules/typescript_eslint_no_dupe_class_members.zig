const parser = @import("parser");
const core = @import("../core.zig");
const no_dupe_class_members = @import("no_dupe_class_members.zig");

const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-dupe-class-members";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const parser.ast.Tree,
    body: parser.ast.ClassBody,
) Allocator.Error!void {
    try no_dupe_class_members.checkWithOptions(allocator, diagnostics, tree, body, .{
        .rule_id = id,
        .severity = .@"error",
    });
}
