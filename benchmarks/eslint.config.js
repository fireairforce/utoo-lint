import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default [
  {
    ignores: ["node_modules/**", "results/**"]
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["fixtures/src/**/*.ts"],
    languageOptions: {
      parserOptions: {
        ecmaVersion: "latest",
        sourceType: "module"
      }
    },
    rules: {
      "no-undef": "off"
    }
  }
];
