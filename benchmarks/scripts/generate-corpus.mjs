import { mkdir, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";

const args = parseArgs(process.argv.slice(2));
const fileCount = positiveInt(args.files, 1000, "files");
const statementsPerFile = positiveInt(args.statements, 30, "statements");
const outDir = args.out ?? "fixtures/src";

await rm(outDir, { recursive: true, force: true });
await mkdir(outDir, { recursive: true });

for (let fileIndex = 0; fileIndex < fileCount; fileIndex += 1) {
  const shard = String(Math.floor(fileIndex / 100)).padStart(3, "0");
  const dir = join(outDir, shard);
  await mkdir(dir, { recursive: true });
  await writeFile(
    join(dir, `module-${String(fileIndex).padStart(5, "0")}.ts`),
    renderModule(fileIndex, statementsPerFile)
  );
}

console.log(
  `Generated ${fileCount} TypeScript file(s) with ${statementsPerFile} statement block(s) each in ${outDir}.`
);

function renderModule(fileIndex, statementsPerFile) {
  const lines = [
    "/* generated benchmark corpus */",
    "",
    `export type BenchmarkRecord${fileIndex} = {`,
    "  readonly id: number;",
    "  readonly name: string;",
    "  readonly active: boolean;",
    "};",
    "",
    `export function compute${fileIndex}(input: number): number {`,
    "  let total = input;",
    "  let marker = 0;"
  ];

  for (let i = 0; i < statementsPerFile; i += 1) {
    const value = (fileIndex + 1) * (i + 3);
    lines.push(`  const value${i} = total + ${value};`);
    lines.push(`  if (value${i} > ${value * 2}) {`);
    lines.push(`    total += value${i} - ${i + 1};`);
    lines.push("  } else {");
    lines.push(`    total += ${i + 1};`);
    lines.push("  }");
    lines.push(`  marker += value${i};`);
  }

  lines.push("  return total + marker;");
  lines.push("}");
  lines.push("");
  lines.push(`export class BenchmarkWorker${fileIndex} {`);
  lines.push("  private total = 0;");
  lines.push("");
  lines.push("  run(input: number): number {");
  lines.push(`    this.total += compute${fileIndex}(input);`);
  lines.push("    return this.total;");
  lines.push("  }");
  lines.push("}");
  lines.push("");
  lines.push(`export const benchmarkRecord${fileIndex}: BenchmarkRecord${fileIndex} = {`);
  lines.push(`  id: ${fileIndex},`);
  lines.push(`  name: "module-${fileIndex}",`);
  lines.push(`  active: ${fileIndex % 2 === 0 ? "true" : "false"}`);
  lines.push("};");
  lines.push("");

  return `${lines.join("\n")}\n`;
}

function parseArgs(argv) {
  const result = {};
  for (const arg of argv) {
    if (!arg.startsWith("--")) {
      throw new Error(`Unknown positional argument: ${arg}`);
    }

    const [rawKey, rawValue] = arg.slice(2).split("=", 2);
    result[rawKey] = rawValue ?? "true";
  }
  return result;
}

function positiveInt(value, fallback, name) {
  if (value === undefined) {
    return fallback;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`--${name} must be a positive integer`);
  }
  return parsed;
}
