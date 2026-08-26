import type { ConfigObject, RuleConfig } from "../index.js";

export type FrontendRuleId =
  | "no-debugger"
  | "no-alert"
  | "no-console"
  | "no-unused-vars"
  | "prefer-const"
  | "eqeqeq"
  | "use-isnan"
  | "valid-typeof"
  | "no-constant-condition"
  | "no-dupe-keys"
  | "no-duplicate-imports"
  | "no-script-url"
  | "import/first"
  | "import/newline-after-import"
  | "import/no-duplicates"
  | "import/no-self-import"
  | "promise/no-nesting"
  | "react-hooks/rules-of-hooks"
  | "react-hooks/exhaustive-deps"
  | "react/jsx-no-duplicate-props"
  | "react/jsx-key"
  | "react/jsx-no-target-blank"
  | "react/jsx-pascal-case"
  | "react/no-array-index-key"
  | "react/no-children-prop"
  | "react/no-danger"
  | "react/no-danger-with-children"
  | "react/no-find-dom-node"
  | "react/no-forward-ref"
  | "react/no-unstable-nested-components"
  | "react/no-unescaped-entities"
  | "react/void-dom-elements-no-children"
  | "jsx-a11y/aria-props"
  | "jsx-a11y/aria-unsupported-elements"
  | "jsx-a11y/iframe-has-title"
  | "jsx-a11y/img-redundant-alt"
  | "jsx-a11y/no-access-key"
  | "unused-imports/no-unused-imports"
  | "@typescript-eslint/ban-types"
  | "@typescript-eslint/no-unused-vars"
  | "@typescript-eslint/no-use-before-define"
  | "@typescript-eslint/no-shadow"
  | "@typescript-eslint/no-redeclare"
  | "@typescript-eslint/no-require-imports"
  | "@typescript-eslint/consistent-type-assertions"
  | "@typescript-eslint/consistent-type-definitions"
  | "@typescript-eslint/no-empty-interface"
  | "@typescript-eslint/no-non-null-asserted-optional-chain";

declare const frontend: ConfigObject & {
  readonly $schema: string;
  readonly files: ["src/**/*.{js,jsx,ts,tsx}"];
  readonly ignores: ["dist", "coverage", "node_modules"];
  readonly rules: Readonly<Record<FrontendRuleId, RuleConfig>>;
};

export default frontend;
