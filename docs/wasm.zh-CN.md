# WebAssembly

`@utoo/lint-wasm` 是 utoo-lint 面向浏览器、仅支持 ESM 的 WebAssembly 发布包。它适用于 lint Playground、编辑器集成、Web Worker，以及对已驻留在内存中的源代码执行 lint 的 Node ESM 程序。

该 WebAssembly 模块是独立式模块：它既不导入 WASI，也不导入宿主文件系统 API。

## 安装

```bash
pnpm add @utoo/lint-wasm
```

包内包含 JavaScript 加载器、TypeScript 类型声明和 `utoo-lint.wasm` 二进制文件。部署浏览器应用时，打包工具或静态资源服务器必须保留构建输出的 Wasm 资源。

## 浏览器 ESM

创建一个 linter，并在多次编辑之间复用：

```js
import { createUtooLint } from "@utoo/lint-wasm";

const linter = await createUtooLint();
const report = linter.lint("const answer = 42; debugger;", {
  filePath: "playground.ts",
  rules: {
    "no-debugger": "error",
    "no-unused-vars": "warn"
  }
});

for (const diagnostic of report.diagnostics) {
  console.log(diagnostic.ruleId, diagnostic.message, diagnostic.range);
}
```

`createUtooLint()` 会异步加载并实例化 Wasm 模块。返回实例的 `lint()` 和 `lintAndFix()` 方法是同步的，因此复用实例的成本很低；但这也意味着交互式 UI 应当从 Web Worker 中调用这些方法。

## Node ESM

异步便捷函数会延迟创建并复用一个默认实例：

```js
import { lint, lintAndFix } from "@utoo/lint-wasm";

const report = await lint("debugger;", {
  filePath: "snippet.js",
  rules: { "no-debugger": "error" }
});

const fixed = await lintAndFix("const value = 1;;;", {
  filePath: "snippet.js",
  rules: { "no-extra-semi": "error" }
});

console.log(report.diagnostics);
console.log(fixed.output);
```

当应用需要显式管理实例，或希望提供自己的 Wasm URL、响应、字节、已编译模块或实例时，请使用 `createUtooLint()`：

```js
const linter = await createUtooLint({
  wasm: new URL("./utoo-lint.wasm", import.meta.url)
});
```

## 内存执行模型

每次调用接受一段源代码字符串和一组选项。`filePath` 是虚拟路径：它的扩展名用于选择 JavaScript、TypeScript、JSX 或 TSX 解析方式，但系统不会实际读取或写入该文件。Wasm 构建不会查找项目配置、展开 glob、遍历目录、解析模块或检查依赖。

`lintAndFix()` 会在 `output` 中返回修复后的源代码，但不会修改文件。该调用产生的诊断描述最终输出，并将 `diagnosticsSource` 设为 `"output"`。普通 `lint()` 的诊断描述输入内容。诊断和修复中的 `range` 值采用 UTF-16 偏移量，因此可以直接用于 JavaScript 字符串和浏览器编辑器 API。

被抑制的问题会单独返回在 `suppressedDiagnostics` 中。

## 规则选择

省略 `rules` 时，将使用 utoo-lint 的内置默认规则集：

```js
linter.lint(source, { filePath: "input.js" });
```

提供 `rules` 对象时，会先从所有 lint 规则均禁用的状态开始，再只启用该对象中的配置项。尤其需要注意，空对象会禁用所有可配置的 lint 规则：

```js
linter.lint(source, { filePath: "input.js", rules: {} });
```

即使 `rules` 为空，解析器诊断仍可能返回，因为处理源代码必须先执行解析。

需要真实项目 I/O 的规则无法在独立式模块中运行。启用这类规则时，调用仍会成功，其规则 ID 会被加入 `skippedRules`，而不是静默假装已经执行项目检查。当前依赖文件系统的规则包括：

- `@alipay/ant/no-phantom-dependencies`
- `@alipay/ant/prefer-import-from-stdlib`
- `import/default`
- `import/export`
- `import/named`
- `import/namespace`
- `import/no-cycle`
- `import/no-named-as-default`
- `import/no-named-as-default-member`
- `import/no-unresolved`

在把 Playground 的运行结果描述为等同于项目级 CLI lint 之前，请检查每次结果中的 `skippedRules`。

## Playground 架构

将已初始化的 linter 保存在长生命周期的 Web Worker 中。只向它发送最新的源代码和选项；如果较新的编辑请求已经进入队列，则在 UI 中丢弃过期响应。

```js
// lint.worker.js
import { createUtooLint } from "@utoo/lint-wasm";

const linterPromise = createUtooLint();

self.onmessage = async ({ data }) => {
  const { id, source, options, fix = false } = data;

  try {
    const linter = await linterPromise;
    const result = fix
      ? linter.lintAndFix(source, options)
      : linter.lint(source, options);
    self.postMessage({ id, result });
  } catch (error) {
    self.postMessage({
      id,
      error: {
        name: error.name,
        code: error.code,
        message: error.message,
        ruleId: error.ruleId
      }
    });
  }
};
```

在主线程上对编辑器事件进行防抖，并为每个请求附加单调递增的 `id`。这样可以让 lint 执行离开渲染线程，同时避免反复编译 Wasm 模块。

## 构建与测试

初始化 Yuku 子模块，使用 `CONTRIBUTING.md` 中记录的 Zig 版本，然后安装工作区依赖：

```bash
git submodule update --init --recursive
pnpm install
```

构建原始独立式模块：

```bash
pnpm build:wasm
```

输出文件为 `zig-out/bin/utoo-lint.wasm`。如需构建并将其复制到 npm 包目录，请运行：

```bash
pnpm package:wasm
```

先运行原始 ABI 和 JavaScript 封装层测试，再运行待发布包和类型声明测试：

```bash
pnpm test:wasm
pnpm --dir npm/@utoo/lint-wasm test
pnpm --dir npm/@utoo/lint-wasm test:types
```

ABI 测试还会验证模块没有任何导入，并暴露预期的内存、分配器、ABI 版本和 lint 入口点。
