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
        } else if (std.mem.eql(u8, arg, "--default-case=off")) {
            options.default_case = false;
        } else if (std.mem.eql(u8, arg, "--default-case-last=off")) {
            options.default_case_last = false;
        } else if (std.mem.eql(u8, arg, "--no-async-promise-executor=off")) {
            options.no_async_promise_executor = false;
        } else if (std.mem.eql(u8, arg, "--no-array-constructor=off")) {
            options.no_array_constructor = false;
        } else if (std.mem.eql(u8, arg, "--no-alert=off")) {
            options.no_alert = false;
        } else if (std.mem.eql(u8, arg, "--no-caller=off")) {
            options.no_caller = false;
        } else if (std.mem.eql(u8, arg, "--no-case-declarations=off")) {
            options.no_case_declarations = false;
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
        } else if (std.mem.eql(u8, arg, "--no-empty-static-block=off")) {
            options.no_empty_static_block = false;
        } else if (std.mem.eql(u8, arg, "--no-else-return=off")) {
            options.no_else_return = false;
        } else if (std.mem.eql(u8, arg, "--no-extra-semi=off")) {
            options.no_extra_semi = false;
        } else if (std.mem.eql(u8, arg, "--no-extra-boolean-cast=off")) {
            options.no_extra_boolean_cast = false;
        } else if (std.mem.eql(u8, arg, "--no-for-in=off")) {
            options.no_for_in = false;
        } else if (std.mem.eql(u8, arg, "--no-global-is-finite=off")) {
            options.no_global_is_finite = false;
        } else if (std.mem.eql(u8, arg, "--no-global-is-nan=off")) {
            options.no_global_is_nan = false;
        } else if (std.mem.eql(u8, arg, "--no-labels=off")) {
            options.no_labels = false;
        } else if (std.mem.eql(u8, arg, "--no-lone-blocks=off")) {
            options.no_lone_blocks = false;
        } else if (std.mem.eql(u8, arg, "--no-lonely-if=off")) {
            options.no_lonely_if = false;
        } else if (std.mem.eql(u8, arg, "--no-multi-str=off")) {
            options.no_multi_str = false;
        } else if (std.mem.eql(u8, arg, "--no-new=off")) {
            options.no_new = false;
        } else if (std.mem.eql(u8, arg, "--no-nested-ternary=off")) {
            options.no_nested_ternary = false;
        } else if (std.mem.eql(u8, arg, "--no-new-func=off")) {
            options.no_new_func = false;
        } else if (std.mem.eql(u8, arg, "--no-new-object=off")) {
            options.no_new_object = false;
        } else if (std.mem.eql(u8, arg, "--no-new-symbol=off")) {
            options.no_new_symbol = false;
        } else if (std.mem.eql(u8, arg, "--no-new-wrappers=off")) {
            options.no_new_wrappers = false;
        } else if (std.mem.eql(u8, arg, "--no-octal=off")) {
            options.no_octal = false;
        } else if (std.mem.eql(u8, arg, "--no-octal-escape=off")) {
            options.no_octal_escape = false;
        } else if (std.mem.eql(u8, arg, "--no-plusplus=off")) {
            options.no_plusplus = false;
        } else if (std.mem.eql(u8, arg, "--no-promise-executor-return=off")) {
            options.no_promise_executor_return = false;
        } else if (std.mem.eql(u8, arg, "--no-proto=off")) {
            options.no_proto = false;
        } else if (std.mem.eql(u8, arg, "--no-regex-spaces=off")) {
            options.no_regex_spaces = false;
        } else if (std.mem.eql(u8, arg, "--no-return-assign=off")) {
            options.no_return_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-script-url=off")) {
            options.no_script_url = false;
        } else if (std.mem.eql(u8, arg, "--no-self-assign=off")) {
            options.no_self_assign = false;
        } else if (std.mem.eql(u8, arg, "--no-self-compare=off")) {
            options.no_self_compare = false;
        } else if (std.mem.eql(u8, arg, "--no-sequences=off")) {
            options.no_sequences = false;
        } else if (std.mem.eql(u8, arg, "--no-sparse-arrays=off")) {
            options.no_sparse_arrays = false;
        } else if (std.mem.eql(u8, arg, "--no-ternary=off")) {
            options.no_ternary = false;
        } else if (std.mem.eql(u8, arg, "--no-throw-literal=off")) {
            options.no_throw_literal = false;
        } else if (std.mem.eql(u8, arg, "--no-unneeded-ternary=off")) {
            options.no_unneeded_ternary = false;
        } else if (std.mem.eql(u8, arg, "--no-unsafe-finally=off")) {
            options.no_unsafe_finally = false;
        } else if (std.mem.eql(u8, arg, "--no-unsafe-negation=off")) {
            options.no_unsafe_negation = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-concat=off")) {
            options.no_useless_concat = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-catch=off")) {
            options.no_useless_catch = false;
        } else if (std.mem.eql(u8, arg, "--no-useless-rename=off")) {
            options.no_useless_rename = false;
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
        \\  --default-case=off        Disable default-case
        \\  --default-case-last=off   Disable default-case-last
        \\  --no-async-promise-executor=off Disable no-async-promise-executor
        \\  --no-array-constructor=off Disable no-array-constructor
        \\  --no-alert=off            Disable no-alert
        \\  --no-caller=off           Disable no-caller
        \\  --no-case-declarations=off Disable no-case-declarations
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
        \\  --no-empty-static-block=off Disable no-empty-static-block
        \\  --no-else-return=off    Disable no-else-return
        \\  --no-extra-semi=off      Disable no-extra-semi
        \\  --no-extra-boolean-cast=off Disable no-extra-boolean-cast
        \\  --no-for-in=off           Disable no-for-in
        \\  --no-global-is-finite=off Disable no-global-is-finite
        \\  --no-global-is-nan=off    Disable no-global-is-nan
        \\  --no-labels=off           Disable no-labels
        \\  --no-lone-blocks=off      Disable no-lone-blocks
        \\  --no-lonely-if=off        Disable no-lonely-if
        \\  --no-multi-str=off        Disable no-multi-str
        \\  --no-new=off              Disable no-new
        \\  --no-nested-ternary=off   Disable no-nested-ternary
        \\  --no-new-func=off         Disable no-new-func
        \\  --no-new-object=off       Disable no-new-object
        \\  --no-new-symbol=off       Disable no-new-symbol
        \\  --no-new-wrappers=off     Disable no-new-wrappers
        \\  --no-octal=off            Disable no-octal
        \\  --no-octal-escape=off     Disable no-octal-escape
        \\  --no-plusplus=off         Disable no-plusplus
        \\  --no-promise-executor-return=off Disable no-promise-executor-return
        \\  --no-proto=off            Disable no-proto
        \\  --no-regex-spaces=off     Disable no-regex-spaces
        \\  --no-return-assign=off    Disable no-return-assign
        \\  --no-script-url=off       Disable no-script-url
        \\  --no-self-assign=off      Disable no-self-assign
        \\  --no-self-compare=off     Disable no-self-compare
        \\  --no-sequences=off        Disable no-sequences
        \\  --no-sparse-arrays=off    Disable no-sparse-arrays
        \\  --no-ternary=off          Disable no-ternary
        \\  --no-throw-literal=off    Disable no-throw-literal
        \\  --no-unneeded-ternary=off Disable no-unneeded-ternary
        \\  --no-unsafe-finally=off   Disable no-unsafe-finally
        \\  --no-unsafe-negation=off  Disable no-unsafe-negation
        \\  --no-useless-concat=off   Disable no-useless-concat
        \\  --no-useless-catch=off    Disable no-useless-catch
        \\  --no-useless-rename=off   Disable no-useless-rename
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
