const std = @import("std");
const core = @import("core.zig");

const Allocator = std.mem.Allocator;

pub const ApplyResult = struct {
    output: []u8,
    applied_diagnostics: usize,
    fixed: bool,

    pub fn deinit(self: *ApplyResult, allocator: Allocator) void {
        allocator.free(self.output);
    }
};

const Candidate = struct {
    diagnostic_index: usize,
    fixes: []const core.Fix,
    start: u32,
    end: u32,
};

const FixRef = struct {
    diagnostic_index: usize,
    fix: *const core.Fix,
};

pub fn apply(
    allocator: Allocator,
    source: []const u8,
    diagnostics: []const core.Diagnostic,
) Allocator.Error!ApplyResult {
    var candidates: std.ArrayList(Candidate) = .empty;
    defer candidates.deinit(allocator);

    for (diagnostics, 0..) |diagnostic, diagnostic_index| {
        if (diagnostic.fixes.len == 0 or !validFixGroup(source, diagnostic.fixes)) continue;

        var start = diagnostic.fixes[0].span.start;
        var end = diagnostic.fixes[0].span.end;
        for (diagnostic.fixes[1..]) |fix| {
            start = @min(start, fix.span.start);
            end = @max(end, fix.span.end);
        }
        try candidates.append(allocator, .{
            .diagnostic_index = diagnostic_index,
            .fixes = diagnostic.fixes,
            .start = start,
            .end = end,
        });
    }

    std.mem.sort(Candidate, candidates.items, {}, candidateLessThan);

    var accepted: std.ArrayList(FixRef) = .empty;
    defer accepted.deinit(allocator);
    var applied_diagnostics: usize = 0;

    for (candidates.items) |candidate| {
        if (conflictsWithAccepted(candidate.fixes, accepted.items)) continue;

        for (candidate.fixes) |*fix| {
            try accepted.append(allocator, .{
                .diagnostic_index = candidate.diagnostic_index,
                .fix = fix,
            });
        }
        applied_diagnostics += 1;
    }

    std.mem.sort(FixRef, accepted.items, {}, fixRefLessThan);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    var cursor: usize = 0;
    for (accepted.items) |entry| {
        const start: usize = @intCast(entry.fix.span.start);
        const end: usize = @intCast(entry.fix.span.end);
        try output.appendSlice(allocator, source[cursor..start]);
        try output.appendSlice(allocator, entry.fix.replacement);
        cursor = end;
    }
    try output.appendSlice(allocator, source[cursor..]);

    const owned_output = try output.toOwnedSlice(allocator);
    const fixed = !std.mem.eql(u8, source, owned_output);
    return .{
        .output = owned_output,
        .applied_diagnostics = if (fixed) applied_diagnostics else 0,
        .fixed = fixed,
    };
}

fn validFixGroup(source: []const u8, fixes: []const core.Fix) bool {
    for (fixes, 0..) |fix, index| {
        if (fix.span.start > fix.span.end or fix.span.end > source.len) return false;

        for (fixes[index + 1 ..]) |other| {
            if (fixesConflict(fix, other)) return false;
        }
    }
    return true;
}

fn conflictsWithAccepted(fixes: []const core.Fix, accepted: []const FixRef) bool {
    for (fixes) |fix| {
        for (accepted) |entry| {
            if (fixesConflict(fix, entry.fix.*)) return true;
        }
    }
    return false;
}

fn fixesConflict(left: core.Fix, right: core.Fix) bool {
    if (left.span.start < right.span.end and right.span.start < left.span.end) return true;

    const left_insertion = left.span.start == left.span.end;
    const right_insertion = right.span.start == right.span.end;
    if (!left_insertion and !right_insertion) return false;

    return left.span.end == right.span.start or right.span.end == left.span.start;
}

fn candidateLessThan(_: void, left: Candidate, right: Candidate) bool {
    if (left.start != right.start) return left.start < right.start;
    if (left.end != right.end) return left.end < right.end;
    return left.diagnostic_index < right.diagnostic_index;
}

fn fixRefLessThan(_: void, left: FixRef, right: FixRef) bool {
    if (left.fix.span.start != right.fix.span.start) return left.fix.span.start < right.fix.span.start;
    if (left.fix.span.end != right.fix.span.end) return left.fix.span.end < right.fix.span.end;
    return left.diagnostic_index < right.diagnostic_index;
}
