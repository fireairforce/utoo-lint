const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_prefer_click_with_debounce = true;
    options.parser_semantic_errors = false;
    return options;
}

test "reports @alipay/ant/prefer-click-with-debounce for async onClick handlers" {
    const source =
        \\async function submit() {}
        \\const save = async () => {};
        \\const memo = useCallback(async () => {}, []);
        \\const view = (
        \\  <>
        \\    <Button onClick={submit} />
        \\    <Button onClick={save} />
        \\    <Button onClick={memo} />
        \\    <Button onClick={async () => {}} />
        \\  </>
        \\);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.alipay_ant_prefer_click_with_debounce.id));
    try std.testing.expectEqualStrings("异步点击事件(async function)必须防抖处理.", result.diagnostics[0].message);
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "reports @alipay/ant/prefer-click-with-debounce for DDD prefixed async definitions" {
    const source =
        \\async function DDDSubmit() {}
        \\const DDDSave = async () => {};
        \\const DDDMemo = useMemoizedFn(async function () {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.alipay_ant_prefer_click_with_debounce.id));
}

test "allows @alipay/ant/prefer-click-with-debounce debounced and sync handlers" {
    const source =
        \\const debounced = useDebounceFn(async () => {});
        \\const locked = useLockFn(async () => {});
        \\const memoDebounced = useCallback(useDebounceFn(async () => {}), []);
        \\const sync = () => {};
        \\const view = (
        \\  <>
        \\    <Button onClick={debounced} />
        \\    <Button onClick={locked} />
        \\    <Button onClick={memoDebounced} />
        \\    <Button onClick={sync} />
        \\  </>
        \\);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_click_with_debounce.id));
}

test "can disable @alipay/ant/prefer-click-with-debounce" {
    const source =
        \\const save = async () => {};
        \\const view = <Button onClick={save} />;
    ;
    var options = optionsOnly();
    options.alipay_ant_prefer_click_with_debounce = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_click_with_debounce.id));
}
