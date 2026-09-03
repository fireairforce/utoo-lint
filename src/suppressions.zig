const std = @import("std");
const parser = @import("parser");
const core = @import("core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

const DirectiveKind = enum {
    ignore,
    ignore_all,
    ignore_start,
    ignore_end,
    eslint_disable,
    eslint_enable,
    eslint_disable_line,
    eslint_disable_next_line,
};

const DirectiveTarget = struct {
    rule_id: ?[]const u8,
    justification: []const u8,

    fn matches(self: DirectiveTarget, rule_id: []const u8) bool {
        return self.rule_id == null or std.mem.eql(u8, self.rule_id.?, rule_id);
    }
};

const ParsedDirective = struct {
    kind: DirectiveKind,
    target: DirectiveTarget,
};

const Directive = struct {
    kind: DirectiveKind,
    target: DirectiveTarget,
    span_start: u32,
    next_code_offset: ?u32 = null,
    top_level: bool = false,
};

pub fn apply(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    suppressed_diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    if (diagnostics.items.len == 0 or tree.comments.len == 0) return;

    var directives = try collectDirectives(allocator, tree);
    defer directives.deinit(allocator);
    if (directives.items.len == 0) return;

    var line_starts = try collectLineStarts(allocator, tree.source);
    defer line_starts.deinit(allocator);

    const decisions = try allocator.alloc(?core.Suppression, diagnostics.items.len);
    defer allocator.free(decisions);
    var suppressed_count: usize = 0;
    for (diagnostics.items, 0..) |diagnostic, index| {
        decisions[index] = suppressionFor(directives.items, line_starts.items, diagnostic);
        if (decisions[index] != null) suppressed_count += 1;
    }
    if (suppressed_count == 0) return;

    var kept: core.DiagnosticList = .empty;
    errdefer kept.deinit(allocator);
    try kept.ensureTotalCapacity(allocator, diagnostics.items.len);
    try suppressed_diagnostics.ensureUnusedCapacity(allocator, suppressed_count);

    const owned_justifications = try allocator.alloc(?[]u8, diagnostics.items.len);
    @memset(owned_justifications, null);
    var ownership_transferred = false;
    defer {
        if (!ownership_transferred) {
            for (owned_justifications) |justification| {
                if (justification) |owned| allocator.free(owned);
            }
        }
        allocator.free(owned_justifications);
    }
    for (decisions, 0..) |decision, index| {
        if (decision) |suppression| {
            owned_justifications[index] = try allocator.dupe(u8, suppression.justification);
        }
    }

    for (diagnostics.items, 0..) |item, index| {
        var diagnostic = item;
        if (owned_justifications[index]) |justification| {
            diagnostic.suppression = .{ .justification = justification };
            suppressed_diagnostics.appendAssumeCapacity(diagnostic);
        } else {
            kept.appendAssumeCapacity(diagnostic);
        }
    }
    ownership_transferred = true;

    diagnostics.deinit(allocator);
    diagnostics.* = kept;
}

fn collectDirectives(allocator: Allocator, tree: *const ast.Tree) Allocator.Error!std.ArrayList(Directive) {
    var directives: std.ArrayList(Directive) = .empty;
    errdefer directives.deinit(allocator);

    for (tree.comments) |comment| {
        const value = tree.string(comment.value);
        if (parseCommentDirective(value)) |parsed| {
            try directives.append(allocator, .{
                .kind = parsed.kind,
                .target = parsed.target,
                .span_start = comment.span.start,
                .next_code_offset = if (parsed.kind == .ignore) nextCodeOffset(tree, comment.span.end) else null,
                .top_level = parsed.kind == .ignore_all and isTopLevelComment(tree, comment),
            });
            continue;
        }
        if (parseEslintDirective(value, comment.type)) |parsed| {
            try appendEslintDirectiveTargets(allocator, &directives, parsed, comment.span.start);
        }
    }

    return directives;
}

fn parseCommentDirective(value: []const u8) ?ParsedDirective {
    const kinds = [_]struct { prefix: []const u8, kind: DirectiveKind }{
        .{ .prefix = "utlint-ignore-start", .kind = .ignore_start },
        .{ .prefix = "utlint-ignore-end", .kind = .ignore_end },
        .{ .prefix = "utlint-ignore-all", .kind = .ignore_all },
        .{ .prefix = "utlint-ignore", .kind = .ignore },
    };
    for (kinds) |entry| {
        if (parseDirectiveTarget(value, entry.prefix)) |target| {
            return .{ .kind = entry.kind, .target = target };
        }
    }
    return null;
}

const ParsedEslintDirective = struct {
    kind: DirectiveKind,
    rules: []const u8,
    justification: []const u8,
};

fn parseEslintDirective(value: []const u8, comment_type: ast.Comment.Type) ?ParsedEslintDirective {
    const trimmed = std.mem.trim(u8, value, " \t\r\n");
    const kinds = [_]struct { prefix: []const u8, kind: DirectiveKind }{
        .{ .prefix = "eslint-disable-next-line", .kind = .eslint_disable_next_line },
        .{ .prefix = "eslint-disable-line", .kind = .eslint_disable_line },
        .{ .prefix = "eslint-disable", .kind = .eslint_disable },
        .{ .prefix = "eslint-enable", .kind = .eslint_enable },
    };
    for (kinds) |entry| {
        if (!std.mem.startsWith(u8, trimmed, entry.prefix)) continue;
        if (trimmed.len > entry.prefix.len and !std.ascii.isWhitespace(trimmed[entry.prefix.len])) continue;
        if (comment_type == .line and (entry.kind == .eslint_disable or entry.kind == .eslint_enable)) continue;

        const tail = trimmed[entry.prefix.len..];
        const separator = eslintDescriptionSeparator(tail);
        return .{
            .kind = entry.kind,
            .rules = std.mem.trim(u8, if (separator) |item| tail[0..item.start] else tail, " \t\r\n"),
            .justification = if (separator) |item| std.mem.trim(u8, tail[item.end..], " \t\r\n") else "",
        };
    }
    return null;
}

const DescriptionSeparator = struct {
    start: usize,
    end: usize,
};

fn eslintDescriptionSeparator(value: []const u8) ?DescriptionSeparator {
    var index: usize = 0;
    while (index < value.len) : (index += 1) {
        if (!std.ascii.isWhitespace(value[index])) continue;

        var end = index + 1;
        while (end < value.len and value[end] == '-') : (end += 1) {}
        if (end < index + 3 or end >= value.len or !std.ascii.isWhitespace(value[end])) continue;
        return .{ .start = index, .end = end + 1 };
    }
    return null;
}

fn appendEslintDirectiveTargets(
    allocator: Allocator,
    directives: *std.ArrayList(Directive),
    parsed: ParsedEslintDirective,
    span_start: u32,
) Allocator.Error!void {
    if (parsed.rules.len == 0) {
        try directives.append(allocator, .{
            .kind = parsed.kind,
            .target = .{ .rule_id = null, .justification = parsed.justification },
            .span_start = span_start,
        });
        return;
    }

    var rules = std.mem.splitScalar(u8, parsed.rules, ',');
    while (rules.next()) |raw_rule_id| {
        const rule_id = std.mem.trim(u8, raw_rule_id, " \t\r\n");
        if (rule_id.len == 0) continue;
        try directives.append(allocator, .{
            .kind = parsed.kind,
            .target = .{ .rule_id = rule_id, .justification = parsed.justification },
            .span_start = span_start,
        });
    }
}

fn parseDirectiveTarget(value: []const u8, prefix: []const u8) ?DirectiveTarget {
    const trimmed = std.mem.trim(u8, value, " \t\r\n");
    if (!std.mem.startsWith(u8, trimmed, prefix)) return null;
    if (trimmed.len == prefix.len) return .{ .rule_id = null, .justification = "" };
    if (trimmed[prefix.len] != ':' and !std.ascii.isWhitespace(trimmed[prefix.len])) return null;

    const tail = std.mem.trim(u8, trimmed[prefix.len..], " \t\r\n");
    const rule_end = std.mem.indexOfScalar(u8, tail, ':') orelse tail.len;
    const rule_id = std.mem.trim(u8, tail[0..rule_end], " \t\r\n");
    const justification = if (rule_end < tail.len)
        std.mem.trim(u8, tail[rule_end + 1 ..], " \t\r\n")
    else
        "";
    return .{
        .rule_id = if (rule_id.len == 0) null else rule_id,
        .justification = justification,
    };
}

fn suppressionFor(
    directives: []const Directive,
    line_starts: []const u32,
    diagnostic: core.Diagnostic,
) ?core.Suppression {
    if (std.mem.eql(u8, diagnostic.rule_id, "parse")) return null;

    const diagnostic_line = lineAtOffset(line_starts, diagnostic.span.start);
    var all_rules_range_depth: usize = 0;
    var named_rule_range_depth: usize = 0;
    var all_rules_range_justification: []const u8 = "";
    var named_rule_range_justification: []const u8 = "";
    var eslint_all_rules_justification: ?[]const u8 = null;
    var eslint_named_rule_justification: ?[]const u8 = null;
    var eslint_rule_enabled_under_all = false;

    for (directives) |directive| {
        if (directive.kind == .eslint_disable_line or directive.kind == .eslint_disable_next_line) {
            const directive_line = lineAtOffset(line_starts, directive.span_start);
            const target_line = directive_line + @intFromBool(directive.kind == .eslint_disable_next_line);
            if (target_line == diagnostic_line and directive.target.matches(diagnostic.rule_id)) {
                return .{ .justification = directive.target.justification };
            }
            continue;
        }
        if (directive.span_start > diagnostic.span.start) continue;

        switch (directive.kind) {
            .ignore_start => {
                if (directive.target.rule_id) |rule_id| {
                    if (std.mem.eql(u8, rule_id, diagnostic.rule_id)) {
                        if (named_rule_range_depth == 0) named_rule_range_justification = directive.target.justification;
                        named_rule_range_depth += 1;
                    }
                } else {
                    if (all_rules_range_depth == 0) all_rules_range_justification = directive.target.justification;
                    all_rules_range_depth += 1;
                }
            },
            .ignore_end => {
                if (directive.target.rule_id) |rule_id| {
                    if (std.mem.eql(u8, rule_id, diagnostic.rule_id) and named_rule_range_depth > 0) named_rule_range_depth -= 1;
                } else if (all_rules_range_depth > 0) {
                    all_rules_range_depth -= 1;
                }
            },
            .ignore_all => {
                if (directive.top_level and directive.target.matches(diagnostic.rule_id)) {
                    return .{ .justification = directive.target.justification };
                }
            },
            .ignore => {
                const next_offset = directive.next_code_offset orelse continue;
                if (lineAtOffset(line_starts, next_offset) == diagnostic_line and directive.target.matches(diagnostic.rule_id)) {
                    return .{ .justification = directive.target.justification };
                }
            },
            .eslint_disable => {
                if (directive.target.rule_id) |rule_id| {
                    if (std.mem.eql(u8, rule_id, diagnostic.rule_id)) {
                        eslint_named_rule_justification = directive.target.justification;
                        eslint_rule_enabled_under_all = false;
                    }
                } else {
                    eslint_all_rules_justification = directive.target.justification;
                    eslint_rule_enabled_under_all = false;
                }
            },
            .eslint_enable => {
                if (directive.target.rule_id) |rule_id| {
                    if (std.mem.eql(u8, rule_id, diagnostic.rule_id)) {
                        eslint_named_rule_justification = null;
                        if (eslint_all_rules_justification != null) eslint_rule_enabled_under_all = true;
                    }
                } else {
                    eslint_all_rules_justification = null;
                    eslint_named_rule_justification = null;
                    eslint_rule_enabled_under_all = false;
                }
            },
            .eslint_disable_line, .eslint_disable_next_line => unreachable,
        }
    }

    if (named_rule_range_depth > 0) return .{ .justification = named_rule_range_justification };
    if (all_rules_range_depth > 0) return .{ .justification = all_rules_range_justification };
    if (eslint_named_rule_justification) |justification| return .{ .justification = justification };
    if (eslint_all_rules_justification) |justification| {
        if (!eslint_rule_enabled_under_all) return .{ .justification = justification };
    }
    return null;
}

fn isTopLevelComment(tree: *const ast.Tree, target: ast.Comment) bool {
    var cursor: usize = if (std.mem.startsWith(u8, tree.source, "\xef\xbb\xbf")) 3 else 0;
    if (std.mem.startsWith(u8, tree.source[cursor..], "#!")) {
        cursor = if (std.mem.indexOfScalarPos(u8, tree.source, cursor, '\n')) |newline|
            newline + 1
        else
            tree.source.len;
    }
    for (tree.comments) |comment| {
        if (comment.span.start >= target.span.start) break;
        const comment_start: usize = @intCast(comment.span.start);
        if (comment_start < cursor) continue;
        if (!isWhitespaceOnly(tree.source[cursor..comment_start])) return false;
        cursor = @intCast(comment.span.end);
    }
    return isWhitespaceOnly(tree.source[cursor..@as(usize, @intCast(target.span.start))]);
}

fn isWhitespaceOnly(value: []const u8) bool {
    for (value) |byte| {
        if (!std.ascii.isWhitespace(byte)) return false;
    }
    return true;
}

fn nextCodeOffset(tree: *const ast.Tree, start: u32) ?u32 {
    var offset: usize = @intCast(start);
    while (offset < tree.source.len) {
        while (offset < tree.source.len and std.ascii.isWhitespace(tree.source[offset])) : (offset += 1) {}
        if (offset == tree.source.len) return null;

        var skipped_comment = false;
        for (tree.comments) |comment| {
            if (comment.span.start < offset) continue;
            if (comment.span.start > offset) break;
            offset = @intCast(comment.span.end);
            skipped_comment = true;
            break;
        }
        if (skipped_comment) continue;

        return @intCast(offset);
    }
    return null;
}

fn collectLineStarts(allocator: Allocator, source: []const u8) Allocator.Error!std.ArrayList(u32) {
    var starts: std.ArrayList(u32) = .empty;
    errdefer starts.deinit(allocator);
    try starts.append(allocator, 0);
    for (source, 0..) |byte, index| {
        if (byte == '\n' and index + 1 < source.len) try starts.append(allocator, @intCast(index + 1));
    }
    return starts;
}

fn lineAtOffset(line_starts: []const u32, offset: u32) usize {
    var low: usize = 0;
    var high = line_starts.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (line_starts[middle] <= offset) {
            low = middle + 1;
        } else {
            high = middle;
        }
    }
    return low;
}
