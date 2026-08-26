import { defineConfig } from "@utoo/lint/config";
import frontend, { type FrontendRuleId } from "@utoo/lint/configs/frontend";

const react19Rule: FrontendRuleId = "react/no-forward-ref";
const nestedComponentRule: FrontendRuleId = "react/no-unstable-nested-components";
const frontendSourcePattern: "src/**/*.{js,jsx,ts,tsx}" = frontend.files[0];
const frontendCoverageIgnore: "coverage" = frontend.ignores[1];
void react19Rule;
void nestedComponentRule;
void frontendSourcePattern;
void frontendCoverageIgnore;

export default defineConfig({
  rules: {
    ...frontend.rules,
  },
});
