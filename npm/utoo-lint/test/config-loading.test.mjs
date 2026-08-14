import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { createRequire } from "node:module";

import { ESLint, lintFiles, lintText, resolveBinary, runCli } from "../index.js";

const require = createRequire(import.meta.url);
const { ESLint: CommonJSESLint, runCli: commonJSRunCli } = require("../index.cjs");

const packageDirectory = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const cliPath = join(packageDirectory, "bin", "utoo-lint.js");
const fishlintPath = join(packageDirectory, "bin", "fishlint.js");
const builtBinary = resolve(
  packageDirectory,
  "..",
  "..",
  "zig-out",
  "bin",
  process.platform === "win32" ? "utoo-lint.exe" : "utoo-lint"
);

function testBinary() {
  if (existsSync(builtBinary)) {
    return builtBinary;
  }
  return resolveBinary();
}

function createProject(t) {
  const project = mkdtempSync(join(tmpdir(), "utoo-lint-config-loading-"));
  t.after(() => rmSync(project, { recursive: true, force: true }));
  return project;
}

function write(path, source = "{}\n") {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, source);
  return path;
}

for (const filename of ["utlint.config.ts", "utlint.config.json"]) {
  test(`ESLint.findConfigFile discovers ${filename}`, async (t) => {
    const project = createProject(t);
    const configPath = write(join(project, filename));

    const eslint = new ESLint({ cwd: project });

    assert.equal(await eslint.findConfigFile(), configPath);
  });
}

test("fishlint applies TypeScript flat config rules per file and keeps CLI overrides highest", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [",
      '  { files: ["src/**/*.ts"], rules: { "no-debugger": "off" } },',
      '  { files: ["test/**/*.ts"], rules: { "no-debugger": "error" } }',
      "];",
      ""
    ].join("\n")
  );
  const disabledSource = write(join(project, "src", "index.ts"), "debugger;\n");
  const enabledSource = write(join(project, "test", "index.ts"), "debugger;\n");
  const env = { ...process.env, UTOO_LINT_BIN: testBinary() };

  const configured = spawnSync(
    process.execPath,
    [fishlintPath, "eslint", "--format=json", disabledSource, enabledSource],
    { cwd: project, env, encoding: "utf8" }
  );

  assert.equal(configured.status, 1, configured.stderr);
  const configuredReport = JSON.parse(configured.stdout);
  assert.deepEqual(
    configuredReport.diagnostics.map((diagnostic) => diagnostic.filePath),
    [enabledSource]
  );
  assert.equal(configuredReport.diagnostics[0].severity, "error");

  const overridden = spawnSync(
    process.execPath,
    [fishlintPath, "eslint", "--format=json", "--rule", "no-debugger: off", disabledSource, enabledSource],
    { cwd: project, env, encoding: "utf8" }
  );

  assert.equal(overridden.status, 0, overridden.stderr);
  assert.deepEqual(JSON.parse(overridden.stdout).diagnostics, []);
});

test("fishlint --rules overrides flat-config off severities", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [",
      '  { files: ["src/**/*.ts"], rules: { "no-debugger": "off" } },',
      '  { files: ["test/**/*.ts"], rules: { "no-debugger": "error" } }',
      "];",
      ""
    ].join("\n")
  );
  const src = write(join(project, "src", "index.ts"), "debugger;\n");
  const testFile = write(join(project, "test", "index.ts"), "debugger;\n");

  const result = spawnSync(
    process.execPath,
    [fishlintPath, "eslint", "--rules=no-debugger", "--format=json", src, testFile],
    { cwd: project, env: { ...process.env, UTOO_LINT_BIN: testBinary() }, encoding: "utf8" }
  );
  const report = JSON.parse(result.stdout);

  assert.equal(result.status, 0, result.stderr);
  assert.equal(report.diagnostics.length, 2);
  assert.ok(report.diagnostics.every((diagnostic) => diagnostic.severity === "warning"));
});

test("fishlint enforces --max-warnings when the native binary exits successfully", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.js"), "debugger;\n");
  const env = { ...process.env, UTOO_LINT_BIN: testBinary() };

  const rejected = spawnSync(
    process.execPath,
    [fishlintPath, "eslint", "--no-config", "--max-warnings=0", sourcePath],
    { cwd: project, env, encoding: "utf8" }
  );
  const accepted = spawnSync(
    process.execPath,
    [fishlintPath, "eslint", "--no-config", "--max-warnings=1", sourcePath],
    { cwd: project, env, encoding: "utf8" }
  );

  assert.equal(rejected.status, 1, rejected.stderr);
  assert.match(rejected.stderr, /too many warnings/);
  assert.equal(accepted.status, 0, accepted.stderr);
});

test("fishlint counts quiet warnings against --max-warnings", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.js"), "debugger;\n");

  const result = spawnSync(
    process.execPath,
    [fishlintPath, "eslint", "--no-config", "--quiet", "--max-warnings=0", sourcePath],
    {
      cwd: project,
      env: { ...process.env, UTOO_LINT_BIN: testBinary() },
      encoding: "utf8"
    }
  );

  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /too many warnings/);
  assert.doesNotMatch(result.stdout, /no-debugger/);
});

test("fishlint groups flat config files by complete rule options", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [",
      '  { files: ["src/**/*.ts"], rules: { "no-console": ["error", { allow: ["warn"] }] } },',
      '  { files: ["test/**/*.ts"], rules: { "no-console": "error" } }',
      "];",
      ""
    ].join("\n")
  );
  const allowedSource = write(join(project, "src", "index.ts"), 'console.warn("allowed");\n');
  const reportedSource = write(join(project, "test", "index.ts"), 'console.warn("reported");\n');

  const result = spawnSync(
    process.execPath,
    [fishlintPath, "eslint", "--format=json", allowedSource, reportedSource],
    { cwd: project, env: { ...process.env, UTOO_LINT_BIN: testBinary() }, encoding: "utf8" }
  );

  assert.equal(result.status, 1, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.filePath), [reportedSource]);
  assert.equal(report.diagnostics[0].ruleId, "no-console");
});

for (const fixFlag of ["--fix", "--fix-dry-run"]) {
  test(`fishlint ${fixFlag} does not leak rules or fixes into an unmatched flat config file`, (t) => {
    const project = createProject(t);
    write(
      join(project, "utlint.config.ts"),
      'export default [{ files: ["test/**/*.js"], rules: { "no-extra-semi": "error" } }];\n'
    );
    const untouchedSource = write(join(project, "src", "index.js"), "foo();;\n");
    const fixedSource = write(join(project, "test", "index.js"), "foo();;\n");

    const result = spawnSync(
      process.execPath,
      [fishlintPath, "eslint", "--format=json", fixFlag, untouchedSource, fixedSource],
      { cwd: project, env: { ...process.env, UTOO_LINT_BIN: testBinary() }, encoding: "utf8" }
    );

    assert.equal(result.status, 0, result.stderr);
    const report = JSON.parse(result.stdout);
    assert.equal(readFileSync(untouchedSource, "utf8"), "foo();;\n");
    assert.equal(
      readFileSync(fixedSource, "utf8"),
      fixFlag === "--fix" ? "foo();\n" : "foo();;\n"
    );
    assert.deepEqual(report.outputs.map((output) => output.filePath), [fixedSource]);
  });
}

for (const fixFlag of ["--fix", "--fix-dry-run"]) {
  test(`fishlint ${fixFlag} does not leak native defaults from an object config`, (t) => {
    const project = createProject(t);
    write(
      join(project, "utlint.config.json"),
      JSON.stringify({ rules: { "no-debugger": "error" } })
    );
    const sourcePath = write(join(project, "index.js"), "foo();;\n");

    const result = spawnSync(
      process.execPath,
      [fishlintPath, "eslint", "--format=json", fixFlag, sourcePath],
      { cwd: project, env: { ...process.env, UTOO_LINT_BIN: testBinary() }, encoding: "utf8" }
    );
    const report = JSON.parse(result.stdout);

    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(report.diagnostics, []);
    assert.deepEqual(report.outputs, []);
    assert.equal(readFileSync(sourcePath, "utf8"), "foo();;\n");
  });
}

test("fishlint applies a flat global ignore entry before per-file rule grouping", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [",
      '  { name: "generated", ignores: ["src/ignored.ts"] },',
      '  { rules: { "no-debugger": "error" } }',
      "];",
      ""
    ].join("\n")
  );
  const ignoredSource = write(join(project, "src", "ignored.ts"), "debugger;\n");
  const reportedSource = write(join(project, "src", "reported.ts"), "debugger;\n");

  const result = spawnSync(
    process.execPath,
    [fishlintPath, "eslint", "--format=json", ignoredSource, reportedSource],
    { cwd: project, env: { ...process.env, UTOO_LINT_BIN: testBinary() }, encoding: "utf8" }
  );

  assert.equal(result.status, 1, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.deepEqual(report.filePaths, [reportedSource]);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.filePath), [reportedSource]);
});

test("fishlint replaces a split --config argument when materializing TypeScript", (t) => {
  const project = createProject(t);
  const configPath = write(
    join(project, "custom.config.ts"),
    'export default { rules: { "no-debugger": "off" } };\n'
  );
  const sourcePath = write(join(project, "index.ts"), "debugger;\n");

  const result = spawnSync(
    process.execPath,
    [fishlintPath, "eslint", "--config", configPath, sourcePath],
    {
      cwd: project,
      env: { ...process.env, UTOO_LINT_BIN: testBinary() },
      encoding: "utf8"
    }
  );

  assert.equal(result.status, 0, result.stderr);
});

test("migrator defaults to utlint.config.json", (t) => {
  const project = createProject(t);
  const eslintConfig = join(project, "eslint.config.mjs");
  write(
    eslintConfig,
    'export default [{ files: ["src/**/*.ts"], rules: { "no-debugger": "error" } }];\n'
  );

  const result = spawnSync(process.execPath, [cliPath, "migrate", "eslint", `--from=${eslintConfig}`], {
    cwd: project,
    encoding: "utf8"
  });
  const outputPath = join(project, "utlint.config.json");

  assert.equal(result.status, 0, result.stderr);
  assert.equal(existsSync(outputPath), true);
  assert.equal(JSON.parse(readFileSync(outputPath, "utf8")).$schema.endsWith("/schema.json"), true);
});

test("migrator config stdout does not corrupt its serialized input", (t) => {
  const project = createProject(t);
  write(
    join(project, "eslint.config.mjs"),
    'console.log("migrate notice");\nexport default [{ rules: { "no-debugger": "error" } }];\n'
  );

  const result = spawnSync(process.execPath, [cliPath, "migrate", "eslint", "--print"], {
    cwd: project,
    env: { ...process.env, UTOO_LINT_BIN: testBinary() },
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).rules["no-debugger"], "error");
});

test("ESLint.findConfigFile prefers utlint.config.ts over utlint.config.json in the same directory", async (t) => {
  const project = createProject(t);
  const typescriptConfig = write(join(project, "utlint.config.ts"));
  write(join(project, "utlint.config.json"));

  const eslint = new ESLint({ cwd: project });

  assert.equal(await eslint.findConfigFile(), typescriptConfig);
});

test("ESLint.findConfigFile searches ancestors from a file path", async (t) => {
  const project = createProject(t);
  const configPath = write(join(project, "utlint.config.json"));
  const sourcePath = write(join(project, "packages", "app", "src", "index.ts"), "export {};\n");

  const eslint = new ESLint({ cwd: join(project, "packages", "app") });

  assert.equal(await eslint.findConfigFile(sourcePath), configPath);
});

test("ESLint.findConfigFile prefers the nearest config directory before filename priority", async (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.ts"));
  const nearestConfig = write(join(project, "packages", "app", "utlint.config.json"));
  const sourcePath = write(join(project, "packages", "app", "src", "index.ts"), "export {};\n");

  const eslint = new ESLint({ cwd: project });

  assert.equal(await eslint.findConfigFile(sourcePath), nearestConfig);
});

test("CLI loads utlint.config.ts and --no-config bypasses it", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "src", "index.ts"), "debugger;\n");
  write(
    join(project, "utlint.config.ts"),
    [
      "type UtlintConfig = { rules: Record<string, \"off\" | \"error\"> };",
      "const config: UtlintConfig = { rules: { \"no-debugger\": \"off\" } };",
      "export default config;",
      ""
    ].join("\n")
  );

  const env = {
    ...process.env,
    UTOO_LINT_BIN: testBinary()
  };
  const configured = spawnSync(process.execPath, [cliPath, sourcePath], {
    cwd: project,
    env,
    encoding: "utf8"
  });
  const unconfigured = spawnSync(process.execPath, [cliPath, "--no-config", sourcePath], {
    cwd: project,
    env,
    encoding: "utf8"
  });

  assert.equal(configured.error, undefined);
  assert.equal(configured.status, 0, configured.stderr);
  assert.equal(unconfigured.error, undefined);
  assert.equal(unconfigured.status, 0, unconfigured.stderr);
  assert.match(unconfigured.stderr, /no-debugger/);
});

test("ESM and CommonJS CLI evaluate a TypeScript config once per lint invocation", (t) => {
  const project = createProject(t);
  const counterPath = write(join(project, "config-load-count.txt"), "0");
  write(
    join(project, "utlint.config.ts"),
    [
      'import { readFileSync, writeFileSync } from "node:fs";',
      `const counterPath = ${JSON.stringify(counterPath)};`,
      'writeFileSync(counterPath, String(Number(readFileSync(counterPath, "utf8")) + 1));',
      'export default { rules: { "no-debugger": "off" } };',
      ""
    ].join("\n")
  );
  const firstSource = write(join(project, "src", "first.ts"), "debugger;\n");
  const secondSource = write(join(project, "src", "second.ts"), "debugger;\n");

  const options = {
    cwd: project,
    binary: testBinary()
  };
  const firstResult = runCli([firstSource, secondSource], options);
  const secondResult = commonJSRunCli([firstSource, secondSource], options);

  assert.equal(firstResult.status, 0, firstResult.stderr);
  assert.equal(secondResult.status, 0, secondResult.stderr);
  assert.equal(readFileSync(counterPath, "utf8"), "2");
});

test("CommonJS API discovers and loads utlint.config.ts", async (t) => {
  const project = createProject(t);
  const configPath = write(
    join(project, "utlint.config.ts"),
    "export default { rules: { \"no-debugger\": \"off\" } };\n"
  );
  const sourcePath = write(join(project, "src", "index.ts"), "debugger;\n");
  const eslint = new CommonJSESLint({ cwd: project, binary: testBinary() });

  assert.equal(await eslint.findConfigFile(sourcePath), configPath);
  const results = await eslint.lintFiles([sourcePath]);
  assert.equal(results[0].messages.length, 0);
});

test("legacy config names remain discoverable after the canonical names", async (t) => {
  for (const filename of ["utoo.json", "utoo-lint.json"]) {
    const project = createProject(t);
    const configPath = write(join(project, filename));
    const eslint = new ESLint({ cwd: project });
    assert.equal(await eslint.findConfigFile(), configPath);
  }
});

test("explicit config and --no-config keep last-argument-wins semantics", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.ts"), "debugger;\n");
  const configPath = write(
    join(project, "custom.config.ts"),
    "export default { rules: { \"no-debugger\": \"off\" } };\n"
  );
  const env = { ...process.env, UTOO_LINT_BIN: testBinary() };

  const configLast = spawnSync(
    process.execPath,
    [cliPath, "--no-config", `--config=${configPath}`, sourcePath],
    { cwd: project, env, encoding: "utf8" }
  );
  const noConfigLast = spawnSync(
    process.execPath,
    [cliPath, `--config=${configPath}`, "--no-config", sourcePath],
    { cwd: project, env, encoding: "utf8" }
  );

  assert.equal(configLast.status, 0, configLast.stderr);
  assert.equal(noConfigLast.status, 0, noConfigLast.stderr);
});

test("split -c loads an explicit TypeScript config", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.ts"), "debugger;\n");
  const configPath = write(
    join(project, "custom.config.ts"),
    'export default { rules: { "no-debugger": "off" } };\n'
  );
  const result = spawnSync(process.execPath, [cliPath, "-c", configPath, sourcePath], {
    cwd: project,
    env: { ...process.env, UTOO_LINT_BIN: testBinary() },
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr);
});

test("invalid TypeScript config failures name the selected file", (t) => {
  const project = createProject(t);
  const configPath = write(join(project, "utlint.config.ts"), "throw new Error(\"config exploded\");\n");
  const sourcePath = write(join(project, "index.ts"), "export {};\n");
  const result = spawnSync(process.execPath, [cliPath, sourcePath], {
    cwd: project,
    env: { ...process.env, UTOO_LINT_BIN: testBinary() },
    encoding: "utf8"
  });

  assert.equal(result.status, 1);
  assert.match(result.stderr, new RegExp(configPath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.match(result.stderr, /config exploded/);
});

test("TypeScript config stdout does not corrupt the serialized config", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    'console.log("config notice");\nexport default { rules: { "no-debugger": "off" } };\n'
  );
  const sourcePath = write(join(project, "index.ts"), "debugger;\n");

  const result = spawnSync(process.execPath, [cliPath, sourcePath], {
    cwd: project,
    env: { ...process.env, UTOO_LINT_BIN: testBinary() },
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr);
  assert.doesNotMatch(result.stderr, /unable to read config|Unexpected token/);
});

test("a broken higher-priority TypeScript config does not fall through to JSON", (t) => {
  const project = createProject(t);
  const configPath = write(join(project, "utlint.config.ts"), "throw new Error(\"selected ts failed\");\n");
  write(join(project, "utlint.config.json"), '{ "rules": { "no-debugger": "off" } }\n');
  const sourcePath = write(join(project, "index.ts"), "debugger;\n");

  const result = spawnSync(process.execPath, [cliPath, sourcePath], {
    cwd: project,
    env: { ...process.env, UTOO_LINT_BIN: testBinary() },
    encoding: "utf8"
  });

  assert.equal(result.status, 1);
  assert.match(result.stderr, new RegExp(configPath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.match(result.stderr, /selected ts failed/);
});

test("raw native binary discovers utlint.config.json in an ancestor", (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.json"), '{ "rules": { "no-debugger": "off" } }\n');
  const packageDirectory = join(project, "packages", "app");
  const sourcePath = write(join(packageDirectory, "index.ts"), "debugger;\n");
  const result = spawnSync(testBinary(), [sourcePath], {
    cwd: packageDirectory,
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr);
});

test("raw native binary treats configured rules as the complete rule set", (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.json"), '{ "rules": { "no-debugger": "error" } }\n');
  const sourcePath = write(join(project, "index.js"), "debugger;\nconst unused = 1;\n");

  const result = spawnSync(testBinary(), ["--format=json", sourcePath], {
    cwd: project,
    encoding: "utf8"
  });
  const report = JSON.parse(result.stdout);

  assert.equal(result.status, 1, result.stderr);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.ruleId), ["no-debugger"]);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.severity), ["error"]);
});

test("raw native binary reports configured warnings without failing", (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.json"), '{ "rules": { "no-debugger": "warn" } }\n');
  const sourcePath = write(join(project, "index.js"), "debugger;\n");

  const result = spawnSync(testBinary(), ["--format=json", sourcePath], {
    cwd: project,
    encoding: "utf8"
  });
  const report = JSON.parse(result.stdout);

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.ruleId), ["no-debugger"]);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.severity), ["warning"]);
});

test("raw native binary groups text diagnostics and supports color overrides", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.js"), 'debugger;\nconsole.log("x");\n');

  const plain = spawnSync(
    testBinary(),
    ["--no-color", "--no-config", "--rules=no-debugger,no-console", sourcePath],
    { cwd: project, encoding: "utf8" }
  );
  assert.equal(plain.status, 0, plain.stderr);
  assert.doesNotMatch(plain.stderr, /\u001b\[/);
  assert.equal(plain.stderr.match(new RegExp(sourcePath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g"))?.length, 1);
  assert.match(plain.stderr, /^\s+1:1\s+warning\s+Unexpected debugger statement\.\s+no-debugger$/m);
  assert.match(plain.stderr, /^\s+2:1\s+warning\s+Unexpected console statement\.\s+no-console$/m);
  assert.match(plain.stderr, /✖ 2 problems \(0 errors, 2 warnings\)/);

  const colored = spawnSync(
    testBinary(),
    ["--color", "--no-config", "--rules=no-debugger", sourcePath],
    { cwd: project, encoding: "utf8", env: { ...process.env, NO_COLOR: "1" } }
  );
  assert.equal(colored.status, 0, colored.stderr);
  assert.match(colored.stderr, /\u001b\[1m/);
  assert.match(colored.stderr, /\u001b\[33mwarning/);

  write(join(project, "utlint.config.json"), '{ "rules": { "no-debugger": "error", "no-console": "warn" } }\n');
  const mixed = spawnSync(testBinary(), ["--no-color", sourcePath], {
    cwd: project,
    encoding: "utf8"
  });
  assert.equal(mixed.status, 1, mixed.stderr);
  assert.match(mixed.stderr, /✖ 2 problems \(1 error, 1 warning\)/);
});

test("raw native binary gives clean and fixable text summaries", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.js"), "const value = 1;\n");

  const clean = spawnSync(testBinary(), ["--no-color", "--no-config", "--rules=no-debugger", sourcePath], {
    cwd: project,
    encoding: "utf8"
  });
  assert.equal(clean.status, 0, clean.stderr);
  assert.equal(clean.stderr, "✓ 1 file checked, no problems found\n");

  writeFileSync(sourcePath, "const value = 1;;\n");
  const fixable = spawnSync(testBinary(), ["--no-color", "--no-config", "--rules=no-extra-semi", sourcePath], {
    cwd: project,
    encoding: "utf8"
  });
  assert.equal(fixable.status, 0, fixable.stderr);
  assert.match(fixable.stderr, /1 problem potentially fixable with the `--fix` option\./);
});

test("raw native binary applies array and numeric config severities", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.js"), "debugger;\n");

  for (const [config, expectedSeverity, expectedStatus] of [
    ['["warn"]', "warning", 0],
    ["1", "warning", 0],
    ['["error"]', "error", 1],
    ["2", "error", 1]
  ]) {
    write(join(project, "utlint.config.json"), `{ "rules": { "no-debugger": ${config} } }\n`);
    const result = spawnSync(testBinary(), ["--format=json", sourcePath], {
      cwd: project,
      encoding: "utf8"
    });
    const report = JSON.parse(result.stdout);

    assert.equal(result.status, expectedStatus, result.stderr);
    assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.severity), [expectedSeverity]);
  }
});

test("raw native binary accepts duplicate names in --rules without changing severity", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.js"), "debugger;\n");

  const result = spawnSync(
    testBinary(),
    ["--no-config", "--rules=no-debugger,no-debugger", "--format=json", sourcePath],
    { cwd: project, encoding: "utf8" }
  );
  const report = JSON.parse(result.stdout);

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.ruleId), ["no-debugger"]);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.severity), ["warning"]);
});

test("raw native binary keeps parse errors fatal with an empty rules config", (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.json"));
  const sourcePath = write(join(project, "index.js"), "const = ;\n");

  const result = spawnSync(testBinary(), ["--format=json", sourcePath], {
    cwd: project,
    encoding: "utf8"
  });
  const report = JSON.parse(result.stdout);

  assert.equal(result.status, 1, result.stderr);
  assert.ok(report.diagnostics.some((diagnostic) => diagnostic.ruleId === "parse" && diagnostic.severity === "error"));
});

test("raw native binary enables no rules for an empty config", (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.json"));
  const sourcePath = write(join(project, "index.js"), "debugger;\nconst unused = 1;\n");

  const result = spawnSync(testBinary(), ["--format=json", sourcePath], {
    cwd: project,
    encoding: "utf8"
  });
  const report = JSON.parse(result.stdout);

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(report.diagnostics, []);
});

test("raw native binary keeps default rules when config discovery is disabled", (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.json"));
  const sourcePath = write(join(project, "index.js"), "debugger;\n");

  const result = spawnSync(testBinary(), ["--no-config", "--format=json", sourcePath], {
    cwd: project,
    encoding: "utf8"
  });
  const report = JSON.parse(result.stdout);

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.ruleId), ["no-debugger"]);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.severity), ["warning"]);
});

test("ESM API loads an ancestor utlint.config.json", async (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.json"), '{ "rules": { "no-debugger": "off" } }\n');
  const appDirectory = join(project, "packages", "app");
  const sourcePath = write(join(appDirectory, "index.ts"), "debugger;\n");
  const eslint = new ESLint({ cwd: appDirectory, binary: testBinary() });

  const results = await eslint.lintFiles([sourcePath]);

  assert.equal(results[0].messages.length, 0);
});

test("ancestor config patterns are relative to the config directory", async (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.json"),
    JSON.stringify({
      files: ["packages/app/src/**/*.ts"],
      rules: { "no-debugger": "off" }
    })
  );
  const appDirectory = join(project, "packages", "app");
  const sourcePath = write(join(appDirectory, "src", "index.ts"), "debugger;\n");
  const eslint = new ESLint({ cwd: appDirectory, binary: testBinary() });

  const config = await eslint.calculateConfigForFile(sourcePath);

  assert.deepEqual(config.rules["no-debugger"], [0]);
});

test("CLI resolves ancestor files and ignores from the config directory", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [{",
      '  files: ["packages/app/src/**/*.ts"],',
      '  ignores: ["packages/app/src/ignored.ts"],',
      '  rules: { "no-debugger": "error" }',
      "}];",
      ""
    ].join("\n")
  );
  const appDirectory = join(project, "packages", "app");
  write(join(appDirectory, "src", "index.ts"), "debugger;\n");
  write(join(appDirectory, "src", "ignored.ts"), "debugger;\n");

  const result = spawnSync(process.execPath, [cliPath], {
    cwd: appDirectory,
    env: { ...process.env, UTOO_LINT_BIN: testBinary() },
    encoding: "utf8"
  });

  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /src\/index\.ts/);
  assert.doesNotMatch(result.stderr, /src\/ignored\.ts/);
});

test("same-directory utlint.config.ts behavior wins over utlint.config.json", async (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.ts"), 'export default { rules: { "no-debugger": "off" } };\n');
  write(join(project, "utlint.config.json"), '{ "rules": { "no-debugger": "error" } }\n');
  const sourcePath = write(join(project, "index.ts"), "debugger;\n");
  const eslint = new ESLint({ cwd: project, binary: testBinary() });

  const results = await eslint.lintFiles([sourcePath]);

  assert.equal(results[0].messages.length, 0);
});

test("a nearer legacy config owns the file before a parent canonical config", async (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.ts"), 'export default { rules: { "no-debugger": "error" } };\n');
  const appDirectory = join(project, "packages", "app");
  write(join(appDirectory, "utoo.json"), '{ "rules": { "no-debugger": "off" } }\n');
  const sourcePath = write(join(appDirectory, "index.ts"), "debugger;\n");
  const eslint = new ESLint({ cwd: appDirectory, binary: testBinary() });

  const results = await eslint.lintFiles([sourcePath]);

  assert.equal(results[0].messages.length, 0);
});

test("utlint.config.ts can import defineConfig and provide default files", (t) => {
  const project = createProject(t);
  const packageLinkDirectory = join(project, "node_modules", "@utoo");
  mkdirSync(packageLinkDirectory, { recursive: true });
  symlinkSync(packageDirectory, join(packageLinkDirectory, "lint"), "dir");
  write(join(project, "src", "index.ts"), "debugger;\n");
  write(
    join(project, "utlint.config.ts"),
    [
      'import { defineConfig } from "@utoo/lint/config";',
      "type Severity = \"off\" | \"error\";",
      "const severity: Severity = \"off\";",
      "export default defineConfig({",
      '  files: ["src/**/*.ts"],',
      '  rules: { "no-debugger": severity }',
      "});",
      ""
    ].join("\n")
  );

  const result = spawnSync(process.execPath, [cliPath], {
    cwd: project,
    env: { ...process.env, UTOO_LINT_BIN: testBinary() },
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr);
});

test("--rules overrides the selected project config", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.ts"), "debugger;\n");
  write(join(project, "utlint.config.json"), '{ "rules": { "no-debugger": "off" } }\n');

  const result = spawnSync(process.execPath, [cliPath, "--rules=no-debugger", sourcePath], {
    cwd: project,
    env: { ...process.env, UTOO_LINT_BIN: testBinary() },
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /no-debugger/);
});

test("utoo-lint text output groups diagnostics by file and summarizes severities", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "src", "index.js"), 'debugger;\nconsole.log("x");\n');

  const result = runCli(
    ["--no-color", "--no-config", "--rules=no-debugger,no-console", sourcePath],
    { cwd: project, binary: testBinary(), encoding: "utf8" }
  );

  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "");
  assert.doesNotMatch(result.stderr, /\u001b\[/);
  assert.equal(result.stderr.match(new RegExp(sourcePath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g"))?.length, 1);
  assert.match(result.stderr, /^\s+1:1\s+warning\s+Unexpected debugger statement\.\s+no-debugger$/m);
  assert.match(result.stderr, /^\s+2:1\s+warning\s+Unexpected console statement\.\s+no-console$/m);
  assert.match(result.stderr, /✖ 2 problems \(0 errors, 2 warnings\)/);
  assert.match(result.stderr, /1 file checked/);

  write(join(project, "utlint.config.json"), '{ "rules": { "no-debugger": "error", "no-console": "warn" } }\n');
  const mixed = runCli(["--no-color", sourcePath], {
    cwd: project,
    binary: testBinary(),
    encoding: "utf8"
  });
  assert.equal(mixed.status, 1, mixed.stderr);
  assert.match(mixed.stderr, /✖ 2 problems \(1 error, 1 warning\)/);
});

test("utoo-lint text output reports clean runs and supports forced color", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.js"), "const value = 1;\n");

  const clean = runCli(["--no-color", "--no-config", "--rules=no-debugger", sourcePath], {
    cwd: project,
    binary: testBinary(),
    encoding: "utf8"
  });
  assert.equal(clean.status, 0, clean.stderr);
  assert.equal(clean.stderr, "✓ 1 file checked, no problems found\n");

  writeFileSync(sourcePath, "debugger;\n");
  const colored = runCli(["--color", "--no-config", "--rules=no-debugger", sourcePath], {
    cwd: project,
    binary: testBinary(),
    encoding: "utf8",
    env: { NO_COLOR: "1" }
  });
  assert.equal(colored.status, 0, colored.stderr);
  assert.match(colored.stderr, /\u001b\[1m/);
  assert.match(colored.stderr, /\u001b\[33mwarning/);
});

test("utoo-lint text output points out autofixable problems", (t) => {
  const project = createProject(t);
  const sourcePath = write(join(project, "index.js"), "const value = 1;;\n");

  const result = runCli(["--no-color", "--no-config", "--rules=no-extra-semi", sourcePath], {
    cwd: project,
    binary: testBinary(),
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /1 problem potentially fixable with the `--fix` option\./);
});

test("later flat config entries can turn a rule back on", async (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [",
      '  { rules: { "no-debugger": "error" } },',
      '  { files: ["src/**/*.ts"], rules: { "no-debugger": "off" } }',
      "];",
      ""
    ].join("\n")
  );
  const disabledSource = write(join(project, "src", "index.ts"), "debugger;\n");
  const enabledSource = write(join(project, "test", "index.ts"), "debugger;\n");
  const eslint = new ESLint({ cwd: project, binary: testBinary() });

  const results = await eslint.lintFiles([disabledSource, enabledSource]);
  const resultByPath = new Map(results.map((result) => [result.filePath, result]));

  assert.equal(resultByPath.get(disabledSource).messages.length, 0);
  assert.match(resultByPath.get(enabledSource).messages[0].ruleId, /no-debugger/);
});

test("flat config rules remain active when the last matching entry disables another file", async (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      'export default [{ files: ["test/**/*.ts"], rules: { "no-debugger": "error" } },',
      '  { files: ["src/**/*.ts"], rules: { "no-debugger": "off" } }];',
      ""
    ].join("\n")
  );
  const disabledSource = write(join(project, "src", "index.ts"), "debugger;\n");
  const enabledSource = write(join(project, "test", "index.ts"), "debugger;\n");
  const eslint = new ESLint({ cwd: project, binary: testBinary() });

  const results = await eslint.lintFiles([disabledSource, enabledSource]);
  const resultByPath = new Map(results.map((result) => [result.filePath, result]));

  assert.equal(resultByPath.get(disabledSource).messages.length, 0);
  assert.match(resultByPath.get(enabledSource).messages[0].ruleId, /no-debugger/);
});

test("a flat config does not leak native default rules that it never enables", async (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.json"),
    JSON.stringify([{ rules: { "no-console": "error" } }])
  );
  const sourcePath = write(join(project, "index.ts"), "debugger;\n");
  const eslint = new ESLint({ cwd: project, binary: testBinary() });

  const results = await eslint.lintFiles([sourcePath]);

  assert.equal(results[0].messages.length, 0);
});

test("flat config rule options are applied to the matching files", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [",
      '  { files: ["src/**/*.ts"], rules: { "no-console": ["error", { allow: ["warn"] }] } },',
      '  { files: ["test/**/*.ts"], rules: { "no-console": "error" } }',
      "];",
      ""
    ].join("\n")
  );
  const allowedSource = write(join(project, "src", "index.ts"), 'console.warn("x");\n');
  const reportedSource = write(join(project, "test", "index.ts"), 'console.warn("x");\n');

  const result = runCli([allowedSource, reportedSource], {
    cwd: project,
    binary: testBinary(),
    encoding: "utf8"
  });

  assert.equal(result.status, 1, result.stderr);
  assert.doesNotMatch(result.stderr, /src\/index\.ts/);
  assert.match(result.stderr, /test\/index\.ts/);
});

test("flat config autofixes only files whose matched config enables the rule", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.json"),
    JSON.stringify([
      { files: ["src/**/*.ts"], rules: { "no-extra-semi": "off" } },
      { files: ["test/**/*.ts"], rules: { "no-extra-semi": "error" } }
    ])
  );
  const untouchedSource = write(join(project, "src", "index.ts"), "const value = 1;;\n");
  const fixedSource = write(join(project, "test", "index.ts"), "const value = 1;;\n");

  const result = runCli(["--fix", untouchedSource, fixedSource], {
    cwd: project,
    binary: testBinary(),
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(untouchedSource, "utf8"), "const value = 1;;\n");
  assert.equal(readFileSync(fixedSource, "utf8"), "const value = 1;\n");
});

test("ESM and CommonJS runCli honor object configs across multiple config roots", (t) => {
  const project = createProject(t);
  const appSource = write(join(project, "packages", "app", "index.js"), "debugger;\n");
  const toolingSource = write(join(project, "packages", "tooling", "index.js"), "console.log(1);\n");
  write(
    join(project, "packages", "app", "utlint.config.json"),
    JSON.stringify({ rules: { "no-debugger": "error" } })
  );
  write(
    join(project, "packages", "tooling", "utlint.config.json"),
    JSON.stringify({ rules: { "no-console": "error" } })
  );
  const options = { cwd: project, binary: testBinary(), encoding: "utf8" };

  for (const execute of [runCli, commonJSRunCli]) {
    const result = execute(["--json", appSource, toolingSource], options);
    const report = JSON.parse(result.stdout);

    assert.equal(result.status, 1, result.stderr);
    assert.deepEqual(
      report.diagnostics.map(({ filePath, ruleId }) => ({ filePath, ruleId })),
      [
        { filePath: appSource, ruleId: "no-debugger" },
        { filePath: toolingSource, ruleId: "no-console" }
      ]
    );
  }
});

for (const [name, targets] of [
  ["directory", ["src", "test"]],
  ["glob", ["src/**/*.js", "test/**/*.js"]]
]) {
  test(`flat config autofix grouping expands ${name} targets before matching`, (t) => {
    const project = createProject(t);
    write(
      join(project, "utlint.config.json"),
      JSON.stringify([
        { files: ["src/**/*.js"], rules: { "no-extra-semi": "off" } },
        { files: ["test/**/*.js"], rules: { "no-extra-semi": "error" } }
      ])
    );
    const untouchedSource = write(join(project, "src", "index.js"), "foo();;\n");
    const fixedSource = write(join(project, "test", "index.js"), "foo();;\n");

    const result = runCli(["--fix", ...targets], {
      cwd: project,
      binary: testBinary(),
      encoding: "utf8"
    });

    assert.equal(result.status, 0, result.stderr);
    assert.equal(readFileSync(untouchedSource, "utf8"), "foo();;\n");
    assert.equal(readFileSync(fixedSource, "utf8"), "foo();\n");
  });
}

test("an unmatched flat config entry means no rules instead of native defaults", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.json"),
    JSON.stringify([{ files: ["test/**/*.js"], rules: { "no-extra-semi": "error" } }])
  );
  const sourcePath = write(join(project, "src", "index.js"), "foo();;\n");

  const result = runCli(["--fix-dry-run", "--json", sourcePath], {
    cwd: project,
    binary: testBinary(),
    encoding: "utf8"
  });
  const report = JSON.parse(result.stdout);

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(report.diagnostics, []);
  assert.deepEqual(report.outputs, []);
  assert.equal(readFileSync(sourcePath, "utf8"), "foo();;\n");
});

test("ESM and CommonJS object configs do not leak native default dry-run fixes", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.json"),
    JSON.stringify({ rules: { "no-debugger": "error" } })
  );
  const sourcePath = write(join(project, "index.js"), "foo();;\n");
  const options = { cwd: project, binary: testBinary(), encoding: "utf8" };

  for (const execute of [runCli, commonJSRunCli]) {
    const result = execute(["--fix-dry-run", "--json", sourcePath], options);
    const report = JSON.parse(result.stdout);

    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(report.diagnostics, []);
    assert.deepEqual(report.outputs, []);
    assert.equal(readFileSync(sourcePath, "utf8"), "foo();;\n");
  }
});

test("CLI --rules enables exactly the requested rules after project config", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.json"),
    JSON.stringify({ rules: { "no-debugger": "off", "no-console": "error" } })
  );
  const sourcePath = write(join(project, "index.js"), "debugger;\nconsole.log(1);\nfoo();;\n");

  const result = spawnSync(
    process.execPath,
    [cliPath, "--rules=no-debugger", "--fix-dry-run", "--json", sourcePath],
    {
      cwd: project,
      env: { ...process.env, UTOO_LINT_BIN: testBinary() },
      encoding: "utf8"
    }
  );
  const report = JSON.parse(result.stdout);

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.ruleId), ["no-debugger"]);
  assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.severity), ["warning"]);
  assert.deepEqual(report.outputs, []);
  assert.equal(readFileSync(sourcePath, "utf8"), "debugger;\nconsole.log(1);\nfoo();;\n");
});

test("CLI --rules preserves per-file options for the selected flat-config rule", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [",
      '  { files: ["src/**/*.ts"], rules: { "no-console": ["error", { allow: ["warn"] }] } },',
      '  { files: ["test/**/*.ts"], rules: { "no-console": "error" } }',
      "];",
      ""
    ].join("\n")
  );
  const allowedSource = write(join(project, "src", "index.ts"), 'console.warn("x");\n');
  const reportedSource = write(join(project, "test", "index.ts"), 'console.warn("x");\n');

  const result = runCli(["--rules=no-console", allowedSource, reportedSource], {
    cwd: project,
    binary: testBinary(),
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr);
  assert.doesNotMatch(result.stderr, /src\/index\.ts/);
  assert.match(result.stderr, /test\/index\.ts/);
});

test("CLI applies flat config rules per file", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [",
      '  { files: ["src/**/*.ts"], rules: { "no-debugger": "off" } },',
      '  { files: ["test/**/*.ts"], rules: { "no-debugger": "error" } }',
      "];",
      ""
    ].join("\n")
  );
  const disabledSource = write(join(project, "src", "index.ts"), "debugger;\n");
  const enabledSource = write(join(project, "test", "index.ts"), "debugger;\n");

  const result = spawnSync(process.execPath, [cliPath, disabledSource, enabledSource], {
    cwd: project,
    env: { ...process.env, UTOO_LINT_BIN: testBinary() },
    encoding: "utf8"
  });

  assert.equal(result.status, 1, result.stderr);
  assert.doesNotMatch(result.stderr, new RegExp(disabledSource.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.match(result.stderr, new RegExp(enabledSource.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
});

test("ESM and CommonJS runCli apply flat config rules per file", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [",
      '  { files: ["src/**/*.ts"], rules: { "no-debugger": "off" } },',
      '  { files: ["test/**/*.ts"], rules: { "no-debugger": "error" } }',
      "];",
      ""
    ].join("\n")
  );
  const disabledSource = write(join(project, "src", "index.ts"), "debugger;\n");
  const enabledSource = write(join(project, "test", "index.ts"), "debugger;\n");
  const options = { cwd: project, binary: testBinary(), encoding: "utf8" };

  for (const execute of [runCli, require("../index.cjs").runCli]) {
    const result = execute([disabledSource, enabledSource], options);
    assert.equal(result.status, 1, result.stderr);
    assert.doesNotMatch(result.stderr, /src\/index\.ts/);
    assert.match(result.stderr, /test\/index\.ts/);
  }
});

test("ESM and CommonJS apply flat overrideConfig rules per file with project config disabled", async (t) => {
  const project = createProject(t);
  const allowedSource = write(join(project, "src", "index.ts"), 'console.warn("x");\n');
  const reportedSource = write(join(project, "test", "index.ts"), 'console.warn("x");\n');
  const overrideConfig = [
    { files: ["src/**/*.ts"], rules: { "no-console": ["error", { allow: ["warn"] }] } },
    { files: ["test/**/*.ts"], rules: { "no-console": "error" } }
  ];

  for (const ESLintConstructor of [ESLint, require("../index.cjs").ESLint]) {
    const eslint = new ESLintConstructor({
      cwd: project,
      binary: testBinary(),
      overrideConfigFile: true,
      overrideConfig
    });
    const results = await eslint.lintFiles([allowedSource, reportedSource]);
    const resultByPath = new Map(results.map((result) => [result.filePath, result]));
    assert.equal(resultByPath.get(allowedSource).messages.length, 0);
    assert.match(resultByPath.get(reportedSource).messages[0].ruleId, /no-console/);
  }
});

test("ESM and CommonJS runCli preserve warning JSON output without failing", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.ts"),
    [
      "export default [",
      '  { files: ["src/**/*.ts"], rules: { "no-debugger": "off" } },',
      '  { files: ["test/**/*.ts"], rules: { "no-debugger": "warn" } }',
      "];",
      ""
    ].join("\n")
  );
  const disabledSource = write(join(project, "src", "index.ts"), "debugger;\n");
  const enabledSource = write(join(project, "test", "index.ts"), "debugger;\n");

  for (const execute of [runCli, commonJSRunCli]) {
    const result = execute(["--json", disabledSource, enabledSource], {
      cwd: project,
      binary: testBinary(),
      encoding: "utf8"
    });
    const report = JSON.parse(result.stdout);

    assert.equal(result.status, 0, result.stderr);
    assert.equal(report.diagnostics.length, 1);
    assert.equal(report.diagnostics[0].severity, "warning");
    assert.match(report.diagnostics[0].filePath, /test\/index\.ts$/);
  }
});

test("ESM and CommonJS keep parse errors fatal when rules are configured", (t) => {
  const project = createProject(t);
  write(join(project, "utlint.config.json"));
  const sourcePath = write(join(project, "index.js"), "const = ;\n");

  for (const execute of [runCli, commonJSRunCli]) {
    const result = execute(["--json", sourcePath], {
      cwd: project,
      binary: testBinary(),
      encoding: "utf8"
    });
    const report = JSON.parse(result.stdout);

    assert.equal(result.status, 1, result.stderr);
    assert.ok(report.diagnostics.some((diagnostic) => diagnostic.ruleId === "parse" && diagnostic.severity === "error"));
  }
});

test("ignored-file warnings do not fail lintFiles or lintText", (t) => {
  const project = createProject(t);
  const ignoredSource = write(join(project, "ignored.js"), "debugger;\n");
  const options = {
    cwd: project,
    binary: testBinary(),
    noConfig: true,
    ignorePatterns: ["ignored.js"]
  };

  for (const execute of [lintFiles, require("../index.cjs").lintFiles]) {
    const report = execute([ignoredSource], options);
    assert.equal(report.exitCode, 0);
    assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.severity), ["warning"]);
  }
  for (const execute of [lintText, require("../index.cjs").lintText]) {
    const report = execute("debugger;\n", { ...options, filePath: ignoredSource });
    assert.equal(report.exitCode, 0);
    assert.deepEqual(report.diagnostics.map((diagnostic) => diagnostic.severity), ["warning"]);
  }
});

test("runCli keeps --fix writes while filtering project config diagnostics", (t) => {
  const project = createProject(t);
  write(
    join(project, "utlint.config.json"),
    JSON.stringify({ rules: { "no-extra-semi": "error" } })
  );
  const sourcePath = write(join(project, "index.ts"), "const value = 1;;\n");

  const result = runCli(["--fix", sourcePath], {
    cwd: project,
    binary: testBinary(),
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(sourcePath, "utf8"), "const value = 1;\n");
});

for (const filename of ["utlint.config.ts", "utlint.config.json"]) {
  test(`fishlint loads ancestor ${filename}`, (t) => {
    const project = createProject(t);
    write(join(project, filename),
      filename.endsWith(".ts")
        ? 'export default { rules: { "no-debugger": "off" } };\n'
        : '{ "rules": { "no-debugger": "off" } }\n');
    const appDirectory = join(project, "packages", "app");
    const sourcePath = write(join(appDirectory, "index.ts"), "debugger;\n");

    const result = spawnSync(process.execPath, [fishlintPath, "eslint", sourcePath], {
      cwd: appDirectory,
      env: { ...process.env, UTOO_LINT_BIN: testBinary() },
      encoding: "utf8"
    });

    assert.equal(result.status, 0, result.stderr);
  });
}
