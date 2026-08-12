import { dirname } from "node:path";
import { writeFileSync } from "node:fs";
import { createJiti } from "jiti";

const configPath = process.argv[2];

try {
  if (!configPath) {
    throw new TypeError("missing config path");
  }
  const jiti = createJiti(dirname(configPath));
  const value = await jiti.import(configPath, { default: true });
  const json = JSON.stringify(value);
  if (json === undefined) {
    throw new TypeError("config did not export a JSON-serializable value");
  }
  // fd 3 is a private serialization channel created by config-loader. Config
  // code may write to stdout without corrupting the JSON payload.
  writeFileSync(3, json);
} catch (error) {
  console.error(error?.stack ?? error?.message ?? String(error));
  process.exitCode = 1;
}
