const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-loss-of-precision";

const max_safe_integer = "9007199254740991";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.NumericLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const raw = tree.string(literal.raw);
    if (!numericLiteralLosesPrecision(raw, literal.kind)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Number literal loses precision.",
        tree.span(index),
    );
}

pub fn numericLiteralLosesPrecision(raw: []const u8, kind: ast.NumericLiteral.Kind) bool {
    var buffer: [256]u8 = undefined;
    const clean = stripSeparators(raw, &buffer) orelse return false;
    if (clean.len == 0) return false;

    return switch (kind) {
        .decimal => decimalLosesPrecision(clean),
        .hex => prefixedIntegerLosesPrecision(clean, 16),
        .octal => octalLosesPrecision(clean),
        .binary => prefixedIntegerLosesPrecision(clean, 2),
    };
}

fn stripSeparators(raw: []const u8, buffer: []u8) ?[]const u8 {
    if (raw.len > buffer.len) return null;

    var len: usize = 0;
    for (raw) |char| {
        if (char == '_') continue;
        buffer[len] = std.ascii.toLower(char);
        len += 1;
    }
    return buffer[0..len];
}

fn decimalLosesPrecision(clean: []const u8) bool {
    if (std.mem.indexOfScalar(u8, clean, 'e') != null) return false;

    if (std.mem.indexOfScalar(u8, clean, '.')) |dot| {
        var significant: usize = 0;
        var seen_non_zero = false;
        for (clean[0..dot]) |char| {
            if (!std.ascii.isDigit(char)) return false;
            if (char != '0') seen_non_zero = true;
            if (seen_non_zero) significant += 1;
        }
        for (clean[dot + 1 ..]) |char| {
            if (!std.ascii.isDigit(char)) return false;
            if (char != '0') seen_non_zero = true;
            if (seen_non_zero) significant += 1;
        }
        return significant > 17;
    }

    const digits = trimLeadingZeros(trimTrailingZeros(clean));
    if (digits.len == 0) return false;
    if (digits.len < max_safe_integer.len) return false;
    if (digits.len > max_safe_integer.len) return true;
    return std.mem.order(u8, digits, max_safe_integer) == .gt;
}

fn octalLosesPrecision(clean: []const u8) bool {
    const digits = if (clean.len >= 2 and clean[0] == '0' and clean[1] == 'o')
        clean[2..]
    else if (clean.len >= 1 and clean[0] == '0')
        clean[1..]
    else
        clean;

    return integerDigitsLosePrecision(digits, 8);
}

fn prefixedIntegerLosesPrecision(clean: []const u8, base: u8) bool {
    if (clean.len < 3) return false;
    return integerDigitsLosePrecision(clean[2..], base);
}

fn integerDigitsLosePrecision(raw_digits: []const u8, base: u8) bool {
    const digits = trimLeadingZeros(raw_digits);
    if (digits.len == 0) return false;

    const bit_len = integerBitLength(digits, base) orelse return false;
    const trailing_zero_bits = integerTrailingZeroBits(digits, base) orelse return false;
    if (bit_len <= trailing_zero_bits) return false;

    return bit_len - trailing_zero_bits > 53;
}

fn integerBitLength(digits: []const u8, base: u8) ?usize {
    const first = std.fmt.charToDigit(digits[0], base) catch return null;
    if (first == 0) return null;

    const leading_bits: usize = @as(usize, @bitSizeOf(u8)) - @clz(first);
    return switch (base) {
        2 => leading_bits + digits.len - 1,
        8 => leading_bits + (digits.len - 1) * 3,
        16 => leading_bits + (digits.len - 1) * 4,
        else => null,
    };
}

fn integerTrailingZeroBits(digits: []const u8, base: u8) ?usize {
    var count: usize = 0;
    var index = digits.len;

    while (index > 0) {
        index -= 1;
        const digit = std.fmt.charToDigit(digits[index], base) catch return null;
        if (digit == 0) {
            count += switch (base) {
                2 => 1,
                8 => 3,
                16 => 4,
                else => return null,
            };
            continue;
        }

        count += @ctz(digit);
        return count;
    }

    return count;
}

fn trimLeadingZeros(value: []const u8) []const u8 {
    var start: usize = 0;
    while (start < value.len and value[start] == '0') : (start += 1) {}
    return value[start..];
}

fn trimTrailingZeros(value: []const u8) []const u8 {
    var end = value.len;
    while (end > 0 and value[end - 1] == '0') : (end -= 1) {}
    return value[0..end];
}
