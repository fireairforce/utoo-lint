const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-misleading-character-class";

const Problem = enum {
    surrogate_pair_without_u_flag,
    surrogate_pair,
    combined,
    emoji_modifier,
    regional_indicator,
    joined,
};

const Problems = struct {
    surrogate_pair_without_u_flag: bool = false,
    surrogate_pair: bool = false,
    combined: bool = false,
    emoji_modifier: bool = false,
    regional_indicator: bool = false,
    joined: bool = false,

    fn set(self: *Problems, problem: Problem) void {
        switch (problem) {
            .surrogate_pair_without_u_flag => self.surrogate_pair_without_u_flag = true,
            .surrogate_pair => self.surrogate_pair = true,
            .combined => self.combined = true,
            .emoji_modifier => self.emoji_modifier = true,
            .regional_indicator => self.regional_indicator = true,
            .joined => self.joined = true,
        }
    }
};

const Character = struct {
    value: u21,
    unicode_code_point_escape: bool = false,
};

pub fn checkRegExpLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.RegExpLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const pattern = tree.string(literal.pattern);
    const flags = tree.string(literal.flags);
    try reportProblems(allocator, diagnostics, tree, index, findProblems(pattern, hasUnicodeFlag(flags)));
}

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.check(ctx.tree, call.callee, call.arguments, index);
        return .proceed;
    }

    pub fn enter_new_expression(
        self: *Visitor,
        expression: ast.NewExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.check(ctx.tree, expression.callee, expression.arguments, index);
        return .proceed;
    }

    fn check(
        self: *Visitor,
        tree: *const ast.Tree,
        callee: ast.NodeIndex,
        argument_range: ast.IndexRange,
        index: ast.NodeIndex,
    ) Allocator.Error!void {
        const arguments = tree.extra(argument_range);
        if (arguments.len == 0) return;
        if (!isGlobalRegExpReference(tree, self.symbol_table, callee)) return;

        const pattern = stringLiteralValue(tree, arguments[0]) orelse return;
        const flags = if (arguments.len >= 2) stringLiteralValue(tree, arguments[1]) orelse return else "";
        try reportProblems(self.allocator, self.diagnostics, tree, index, findProblems(pattern, hasUnicodeFlag(flags)));
    }
};

fn reportProblems(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    problems: Problems,
) Allocator.Error!void {
    if (problems.surrogate_pair_without_u_flag) {
        try reportProblem(allocator, diagnostics, tree, index, .surrogate_pair_without_u_flag);
    }
    if (problems.surrogate_pair) {
        try reportProblem(allocator, diagnostics, tree, index, .surrogate_pair);
    }
    if (problems.combined) {
        try reportProblem(allocator, diagnostics, tree, index, .combined);
    }
    if (problems.emoji_modifier) {
        try reportProblem(allocator, diagnostics, tree, index, .emoji_modifier);
    }
    if (problems.regional_indicator) {
        try reportProblem(allocator, diagnostics, tree, index, .regional_indicator);
    }
    if (problems.joined) {
        try reportProblem(allocator, diagnostics, tree, index, .joined);
    }
}

fn reportProblem(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    problem: Problem,
) Allocator.Error!void {
    const message = switch (problem) {
        .surrogate_pair_without_u_flag => "Unexpected surrogate pair in character class. Use 'u' flag.",
        .surrogate_pair => "Unexpected surrogate pair in character class.",
        .combined => "Unexpected combined character in character class.",
        .emoji_modifier => "Unexpected modified Emoji in character class.",
        .regional_indicator => "Unexpected national flag in character class.",
        .joined => "Unexpected joined character sequence in character class.",
    };

    try core.addDiagnostic(allocator, diagnostics, .warning, id, message, tree.span(index));
}

fn findProblems(pattern: []const u8, unicode: bool) Problems {
    var problems = Problems{};
    var i: usize = 0;
    var in_class = false;
    var previous: ?Character = null;
    var pending_zwj = false;

    while (i < pattern.len) {
        const byte = pattern[i];

        if (byte == '\\') {
            i += 1;
            const maybe_character = readEscapedCharacter(pattern, &i);
            if (!in_class) continue;

            const character = maybe_character orelse {
                resetSequence(&previous, &pending_zwj);
                continue;
            };
            checkCharacter(&problems, unicode, character, &previous, &pending_zwj);
            continue;
        }

        if (!in_class and byte == '[') {
            i += 1;
            in_class = true;
            resetSequence(&previous, &pending_zwj);
            continue;
        }
        if (in_class and byte == ']') {
            i += 1;
            in_class = false;
            resetSequence(&previous, &pending_zwj);
            continue;
        }

        const character = readRawCharacter(pattern, &i) orelse {
            resetSequence(&previous, &pending_zwj);
            continue;
        };
        if (!in_class) continue;

        checkCharacter(&problems, unicode, character, &previous, &pending_zwj);
    }

    return problems;
}

fn checkCharacter(
    problems: *Problems,
    unicode: bool,
    character: Character,
    previous: *?Character,
    pending_zwj: *bool,
) void {
    if (!unicode and character.value > 0xffff and !character.unicode_code_point_escape) {
        problems.set(.surrogate_pair_without_u_flag);
    }

    if (pending_zwj.* and character.value != 0x200d) {
        problems.set(.joined);
    }
    pending_zwj.* = false;

    if (previous.*) |prev| {
        if (isSurrogatePair(prev.value, character.value)) {
            if (!unicode and !prev.unicode_code_point_escape and !character.unicode_code_point_escape) {
                problems.set(.surrogate_pair_without_u_flag);
            } else {
                problems.set(.surrogate_pair);
            }
        }

        if (isCombiningCharacter(character.value) and !isCombiningCharacter(prev.value)) {
            problems.set(.combined);
        }

        if (isEmojiModifier(character.value) and !isEmojiModifier(prev.value)) {
            problems.set(.emoji_modifier);
        }

        if (isRegionalIndicatorSymbol(character.value) and isRegionalIndicatorSymbol(prev.value)) {
            problems.set(.regional_indicator);
        }

        if (character.value == 0x200d and prev.value != 0x200d) {
            pending_zwj.* = true;
        }
    }

    previous.* = character;
}

fn resetSequence(previous: *?Character, pending_zwj: *bool) void {
    previous.* = null;
    pending_zwj.* = false;
}

fn readRawCharacter(pattern: []const u8, i: *usize) ?Character {
    if (i.* >= pattern.len) return null;

    const byte = pattern[i.*];
    i.* += 1;

    if (byte < 0x80) return .{ .value = byte };

    const width = std.unicode.utf8ByteSequenceLength(byte) catch return null;
    if (i.* - 1 + width > pattern.len) return null;
    const cp = std.unicode.utf8Decode(pattern[i.* - 1 .. i.* - 1 + width]) catch return null;
    i.* = i.* - 1 + width;
    return .{ .value = cp };
}

fn readEscapedCharacter(pattern: []const u8, i: *usize) ?Character {
    if (i.* >= pattern.len) return null;

    const first = pattern[i.*];
    i.* += 1;
    if (first != 'u') {
        if (isCharacterSetEscape(first)) return null;
        if (readControlEscape(first)) |cp| return .{ .value = cp };
        if (first == 'x') {
            if (readFixedHexEscape(pattern, i, 2)) |cp| return .{ .value = cp };
        }
        return .{ .value = first };
    }

    if (i.* < pattern.len and pattern[i.*] == '{') {
        const start = i.* + 1;
        var end = start;
        while (end < pattern.len and pattern[end] != '}') : (end += 1) {}
        if (end >= pattern.len) return .{ .value = 'u' };
        i.* = end + 1;
        return .{
            .value = std.fmt.parseInt(u21, pattern[start..end], 16) catch return null,
            .unicode_code_point_escape = true,
        };
    }

    return .{ .value = readFixedHexEscape(pattern, i, 4) orelse 'u' };
}

fn readFixedHexEscape(pattern: []const u8, i: *usize, comptime len: usize) ?u21 {
    if (i.* + len > pattern.len) return null;
    const cp = std.fmt.parseInt(u21, pattern[i.* .. i.* + len], 16) catch return null;
    i.* += len;
    return cp;
}

fn isCharacterSetEscape(char: u8) bool {
    return switch (char) {
        'd', 'D', 's', 'S', 'w', 'W', 'p', 'P' => true,
        else => false,
    };
}

fn readControlEscape(char: u8) ?u21 {
    return switch (char) {
        'f' => 0x0c,
        'n' => 0x0a,
        'r' => 0x0d,
        't' => 0x09,
        'v' => 0x0b,
        '0' => 0x00,
        'b' => 0x08,
        else => null,
    };
}

fn isSurrogatePair(lead: u21, tail: u21) bool {
    return lead >= 0xd800 and lead < 0xdc00 and tail >= 0xdc00 and tail < 0xe000;
}

fn isCombiningMark(cp: u21) bool {
    return (cp >= 0x0300 and cp <= 0x036f) or
        (cp >= 0x1ab0 and cp <= 0x1aff) or
        (cp >= 0x1dc0 and cp <= 0x1dff) or
        (cp >= 0x20d0 and cp <= 0x20ff) or
        (cp >= 0xfe20 and cp <= 0xfe2f);
}

fn isCombiningCharacter(cp: u21) bool {
    return isCombiningMark(cp) or isVariationSelector(cp);
}

fn isEmojiModifier(cp: u21) bool {
    return cp >= 0x1f3fb and cp <= 0x1f3ff;
}

fn isRegionalIndicatorSymbol(cp: u21) bool {
    return cp >= 0x1f1e6 and cp <= 0x1f1ff;
}

fn isVariationSelector(cp: u21) bool {
    return (cp >= 0xfe00 and cp <= 0xfe0f) or (cp >= 0xe0100 and cp <= 0xe01ef);
}

fn hasUnicodeFlag(flags: []const u8) bool {
    return std.mem.indexOfScalar(u8, flags, 'u') != null;
}

fn isGlobalRegExpReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    const name = identifierReferenceName(tree, unwrapped) orelse return false;
    return std.mem.eql(u8, name, "RegExp") and isUnresolvedReference(symbol_table, unwrapped);
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
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

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isUnresolvedReference(
    symbol_table: traverser.semantic.SymbolTable,
    node: ast.NodeIndex,
) bool {
    return symbol_table.isUnresolvedReference(node);
}
