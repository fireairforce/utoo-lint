# 快速开始

在现有 JavaScript 或 TypeScript 项目中安装并运行 `utoo-lint`，然后按需添加
带类型的项目配置，用来选择规则和检查文件。

## 环境要求

npm 包要求 Node.js 20 或更高版本。它会在受支持的 macOS、Linux 和 Windows
平台上安装预编译的原生二进制文件，因此使用 npm 包不需要 Zig 工具链。

## 安装

使用项目现有的包管理器：

```bash
# pnpm
pnpm add -D @utoo/lint

# npm
npm install --save-dev @utoo/lint

# utoo
ut install @utoo/lint -D
```

## 第一次检查

让 CLI 检查源码目录。没有配置文件时，utoo-lint 会使用内置默认规则。

```bash
pnpm exec utoo-lint src
```

使用 npm 时运行 `npx utoo-lint src`；使用 utoo 时运行
`utx @utoo/lint src`。

## 添加带类型的配置

在项目根目录创建 `utlint.config.ts`。前端预设提供一套适用于 JavaScript、
TypeScript、React、import 和 JSX 无障碍规则的实用起点。

```ts
import { defineConfig } from "@utoo/lint/config";
import frontend from "@utoo/lint/configs/frontend";

export default defineConfig({
  ...frontend,
  ignores: [...frontend.ignores, ".next", "storybook-static"],
  rules: {
    ...frontend.rules,
    "no-console": "off"
  }
});
```

该预设自带 `files` 模式，因此 CLI 无需位置参数也能找到源码文件：

```bash
pnpm exec utoo-lint
```

如需了解扁平配置数组、静态 JSON 配置、全局忽略、规则选项和优先级，请阅读
[配置文档](/zh-CN/configuration)。

## 添加 package scripts

在 `package.json` 中加入可重复执行的检查命令：

```json
{
  "scripts": {
    "lint": "utoo-lint src",
    "lint:fix": "utoo-lint --fix src"
  }
}
```

使用项目的包管理器运行这些脚本，例如 `pnpm lint` 和 `pnpm lint:fix`。

## 后续阅读

- 查看完整的[规则覆盖情况](/zh-CN/rule-status)。
- 按照 [ESLint 迁移指南](/zh-CN/eslint-migration)迁移现有项目。
- 通过[抑制注释](/zh-CN/suppressions)记录有意保留的例外。
- 无需安装，直接在 [Playground](/playground/) 中检查单个文件。
