import { defineConfig } from "@utoo/lint/config";
import frontend, { type FrontendRuleId } from "@utoo/lint/configs/frontend";

const react19Rule: FrontendRuleId = "react/no-forward-ref";
const nestedComponentRule: FrontendRuleId = "react/no-unstable-nested-components";
void react19Rule;
void nestedComponentRule;

export default defineConfig({
  rules: {
    ...frontend.rules,
  },
});
