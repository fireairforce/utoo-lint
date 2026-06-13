const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_exhaustive_deps = true;
    return options;
}

test "reports @alipay/ant/exhaustive-deps hook callback problems" {
    const source =
        \\function App() {
        \\  useEffect();
        \\  useMemo(() => value);
        \\  useEffect(async () => {}, []);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "test.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.alipay_ant_exhaustive_deps.id));
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[0].message, "requires an effect callback") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[1].message, "does nothing when called with only one argument") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[2].message, "Effect callbacks are synchronous") != null);
}

test "reports @alipay/ant/exhaustive-deps dependency array problems" {
    const source =
        \\function App({ foo, bar, deps }) {
        \\  useEffect(() => { console.log(foo); }, []);
        \\  useEffect(() => { console.log(foo); }, [foo, foo]);
        \\  useEffect(() => { console.log(foo); }, deps);
        \\  useEffect(() => { console.log(foo); }, [...deps]);
        \\  useEffect(() => {}, [foo + bar]);
        \\  useEffect(() => {}, ['foo']);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "test.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 8), helpers.countRule(result, lint.rules.alipay_ant_exhaustive_deps.id));
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[0].message, "missing dependency: 'foo'") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[1].message, "duplicate dependency: 'foo'") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[2].message, "not an array literal") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[3].message, "missing dependency: 'foo'") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[4].message, "spread element") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[5].message, "missing dependency: 'foo'") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[6].message, "complex expression") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[7].message, "literal is not a valid dependency") != null);
}

test "tracks @alipay/ant/exhaustive-deps member and imperative handle dependencies" {
    const source =
        \\function App(props, ref) {
        \\  useEffect(() => { console.log(props.foo.bar); }, []);
        \\  useEffect(() => { console.log(props.foo.bar); }, [props.foo]);
        \\  useImperativeHandle(ref, () => props.value, []);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "test.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_ant_exhaustive_deps.id));
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[0].message, "missing dependency: 'props.foo.bar'") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[1].message, "missing dependency: 'props.value'") != null);
}

test "allows @alipay/ant/exhaustive-deps stable values" {
    const source =
        \\const moduleValue = compute();
        \\function helper() {}
        \\function App() {
        \\  const literal = 1;
        \\  const ref = useRef();
        \\  const [state, setState] = useState(0);
        \\  useEffect(() => {
        \\    console.log(moduleValue, literal, ref.current);
        \\    helper();
        \\    setState(1);
        \\  }, []);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "test.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_exhaustive_deps.id));
}

test "can disable @alipay/ant/exhaustive-deps" {
    const source =
        \\function App({ foo }) {
        \\  useEffect(() => { console.log(foo); }, []);
        \\}
    ;

    var options = optionsOnly();
    options.alipay_ant_exhaustive_deps = false;
    var result = try lint.lintSource(std.testing.allocator, source, "test.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_exhaustive_deps.id));
}
