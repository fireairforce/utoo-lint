const std = @import("std");
const lint = @import("utoo_lint");

const max_file_size = 64 * 1024 * 1024;

const Stats = struct {
    files: usize = 0,
    diagnostics: usize = 0,
    errors: usize = 0,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var options = lint.Options{};
    var targets: std.ArrayList([]const u8) = .empty;
    defer targets.deinit(allocator);

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            return;
        } else if (std.mem.eql(u8, arg, "--no-array-constructor=off")) {
            options.no_array_constructor = false;
        } else if (std.mem.eql(u8, arg, "--no-alert=off")) {
            options.no_alert = false;
        } else if (std.mem.eql(u8, arg, "--no-caller=off")) {
            options.no_caller = false;
        } else if (std.mem.eql(u8, arg, "--no-cond-assign=off")) {
            options.no_cond_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-compare-neg-zero=off")) {
            options.no_compare_neg_zero = false;
        } else if (std.mem.eql(u8, arg, "--no-constant-condition=off")) {
            options.no_constant_condition = false;
        } else if (std.mem.eql(u8, arg, "--no-control-regex=off")) {
            options.no_control_regex = false;
        } else if (std.mem.eql(u8, arg, "--no-console=off")) {
            options.no_console = false;
        } else if (std.mem.eql(u8, arg, "--no-comma-operator=off")) {
            options.no_comma_operator = false;
        } else if (std.mem.eql(u8, arg, "--no-debugger=off")) {
            options.no_debugger = false;
        } else if (std.mem.eql(u8, arg, "--no-duplicate-case=off")) {
            options.no_duplicate_case = false;
        } else if (std.mem.eql(u8, arg, "--no-dupe-keys=off")) {
            options.no_dupe_keys = false;
        } else if (std.mem.eql(u8, arg, "--no-delete-var=off")) {
            options.no_delete_var = false;
        } else if (std.mem.eql(u8, arg, "--no-empty-block-statements=off")) {
            options.no_empty_block_statements = false;
        } else if (std.mem.eql(u8, arg, "--no-empty-character-class=off")) {
            options.no_empty_character_class = false;
        } else if (std.mem.eql(u8, arg, "--no-empty-pattern=off")) {
            options.no_empty_pattern = false;
        } else if (std.mem.eql(u8, arg, "--no-extra-boolean-cast=off")) {
            options.no_extra_boolean_cast = false;
        } else if (std.mem.eql(u8, arg, "--no-for-in=off")) {
            options.no_for_in = false;
        } else if (std.mem.eql(u8, arg, "--no-global-is-finite=off")) {
            options.no_global_is_finite = false;
        } else if (std.mem.eql(u8, arg, "--no-global-is-nan=off")) {
            options.no_global_is_nan = false;
        } else if (std.mem.eql(u8, arg, "--no-new-func=off")) {
            options.no_new_func = false;
        } else if (std.mem.eql(u8, arg, "--no-new-object=off")) {
            options.no_new_object = false;
        } else if (std.mem.eql(u8, arg, "--no-new-symbol=off")) {
            options.no_new_symbol = false;
        } else if (std.mem.eql(u8, arg, "--no-new-wrappers=off")) {
            options.no_new_wrappers = false;
        } else if (std.mem.eql(u8, arg, "--no-proto=off")) {
            options.no_proto = false;
        } else if (std.mem.eql(u8, arg, "--no-regex-spaces=off")) {
            options.no_regex_spaces = false;
        } else if (std.mem.eql(u8, arg, "--no-self-compare=off")) {
            options.no_self_compare = false;
        } else if (std.mem.eql(u8, arg, "--no-sparse-arrays=off")) {
            options.no_sparse_arrays = false;
        } else if (std.mem.eql(u8, arg, "--no-unsafe-negation=off")) {
            options.no_unsafe_negation = false;
        } else if (std.mem.eql(u8, arg, "--no-void=off")) {
            options.no_void = false;
        } else if (std.mem.eql(u8, arg, "--no-with=off")) {
            options.no_with = false;
        } else if (std.mem.eql(u8, arg, "--no-var=off")) {
            options.no_var = false;
        } else if (std.mem.eql(u8, arg, "--eqeqeq=off")) {
            options.eqeqeq = false;
        } else if (std.mem.eql(u8, arg, "--use-isnan=off")) {
            options.use_isnan = false;
        } else if (std.mem.eql(u8, arg, "--no-unused-vars=off")) {
            options.no_unused_vars = false;
        } else if (std.mem.eql(u8, arg, "--no-undef=off")) {
            options.no_undef = false;
        } else if (std.mem.eql(u8, arg, "--semantic-errors=off")) {
            options.parser_semantic_errors = false;
        } else {
            try targets.append(allocator, arg);
        }
    }

    if (targets.items.len == 0) {
        try targets.append(allocator, ".");
    }

    var stats = Stats{};
    for (targets.items) |target| {
        try lintPath(allocator, io, target, options, &stats);
    }

    std.debug.print("{d} file(s) checked, {d} diagnostic(s)\n", .{
        stats.files,
        stats.diagnostics,
    });

    if (stats.errors > 0 or stats.diagnostics > 0) {
        std.process.exit(1);
    }
}

fn lintPath(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    options: lint.Options,
    stats: *Stats,
) !void {
    const cwd = std.Io.Dir.cwd();
    const stat = cwd.statFile(io, path, .{}) catch |err| {
        std.debug.print("{s}: unable to stat path: {s}\n", .{ path, @errorName(err) });
        stats.errors += 1;
        stats.diagnostics += 1;
        return;
    };

    switch (stat.kind) {
        .file => {
            if (lint.isLintablePath(path)) {
                try lintFile(allocator, io, path, options, stats);
            }
        },
        .directory => try lintDirectory(allocator, io, path, options, stats),
        else => {},
    }
}

fn lintDirectory(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    options: lint.Options,
    stats: *Stats,
) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    defer dir.close(io);

    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (shouldSkipDirectoryEntry(entry.name)) continue;

        const child_path = try std.fs.path.join(allocator, &.{ path, entry.name });
        defer allocator.free(child_path);

        switch (entry.kind) {
            .file => {
                if (lint.isLintablePath(child_path)) {
                    try lintFile(allocator, io, child_path, options, stats);
                }
            },
            .directory => try lintDirectory(allocator, io, child_path, options, stats),
            else => {},
        }
    }
}

fn lintFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    options: lint.Options,
    stats: *Stats,
) !void {
    const source = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_file_size)) catch |err| {
        std.debug.print("{s}: unable to read file: {s}\n", .{ path, @errorName(err) });
        stats.errors += 1;
        stats.diagnostics += 1;
        return;
    };
    defer allocator.free(source);

    var result = try lint.lintSource(allocator, source, path, options);
    defer result.deinit(allocator);

    stats.files += 1;

    for (result.diagnostics) |diagnostic| {
        const position = lint.offsetToLineColumn(source, diagnostic.span.start);
        std.debug.print("{s}:{d}:{d}: {s}: {s} [{s}]\n", .{
            path,
            position.line,
            position.column,
            diagnostic.severity.toString(),
            diagnostic.message,
            diagnostic.rule_id,
        });

        stats.diagnostics += 1;
        if (diagnostic.severity == .@"error") {
            stats.errors += 1;
        }
    }
}

fn shouldSkipDirectoryEntry(name: []const u8) bool {
    return std.mem.eql(u8, name, ".git") or
        std.mem.eql(u8, name, ".zig-cache") or
        std.mem.eql(u8, name, "node_modules") or
        std.mem.eql(u8, name, "vendor") or
        std.mem.eql(u8, name, "zig-out");
}

fn printHelp() void {
    std.debug.print(
        \\Usage:
        \\  utoo-lint [options] [file-or-directory ...]
        \\
        \\Options:
        \\  --no-array-constructor=off Disable no-array-constructor
        \\  --no-alert=off            Disable no-alert
        \\  --no-caller=off           Disable no-caller
        \\  --no-cond-assign=off      Disable no-cond-assign
        \\  --no-compare-neg-zero=off Disable no-compare-neg-zero
        \\  --no-constant-condition=off Disable no-constant-condition
        \\  --no-control-regex=off   Disable no-control-regex
        \\  --no-comma-operator=off   Disable no-comma-operator
        \\  --no-console=off          Disable no-console
        \\  --no-debugger=off         Disable no-debugger
        \\  --no-duplicate-case=off   Disable no-duplicate-case
        \\  --no-dupe-keys=off        Disable no-dupe-keys
        \\  --no-delete-var=off       Disable no-delete-var
        \\  --no-empty-block-statements=off Disable no-empty-block-statements
        \\  --no-empty-character-class=off Disable no-empty-character-class
        \\  --no-empty-pattern=off  Disable no-empty-pattern
        \\  --no-extra-boolean-cast=off Disable no-extra-boolean-cast
        \\  --no-for-in=off           Disable no-for-in
        \\  --no-global-is-finite=off Disable no-global-is-finite
        \\  --no-global-is-nan=off    Disable no-global-is-nan
        \\  --no-new-func=off         Disable no-new-func
        \\  --no-new-object=off       Disable no-new-object
        \\  --no-new-symbol=off       Disable no-new-symbol
        \\  --no-new-wrappers=off     Disable no-new-wrappers
        \\  --no-proto=off            Disable no-proto
        \\  --no-regex-spaces=off     Disable no-regex-spaces
        \\  --no-self-compare=off     Disable no-self-compare
        \\  --no-sparse-arrays=off    Disable no-sparse-arrays
        \\  --no-unsafe-negation=off  Disable no-unsafe-negation
        \\  --no-void=off             Disable no-void
        \\  --no-with=off             Disable no-with
        \\  --no-var=off              Disable no-var
        \\  --eqeqeq=off              Disable eqeqeq
        \\  --use-isnan=off           Disable use-isnan
        \\  --no-unused-vars=off      Disable no-unused-vars
        \\  --no-undef=off            Disable no-undef
        \\  --semantic-errors=off     Disable parser semantic errors
        \\
    , .{});
}
