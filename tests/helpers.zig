const std = @import("std");
const lint = @import("utoo_lint");

pub fn hasRule(result: lint.Result, rule_id: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return true;
    }
    return false;
}

pub fn countRule(result: lint.Result, rule_id: []const u8) usize {
    var count: usize = 0;
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) count += 1;
    }
    return count;
}
