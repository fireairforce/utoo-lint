# Rule status

This document tracks the ESLint-compatible rules currently implemented by `utoo-lint`.
Each rule links to the corresponding ESLint rule reference.

| Rule | Status |
| --- | --- |
| [`accessor-pairs`](https://eslint.org/docs/latest/rules/accessor-pairs) | Implemented for optional `setWithoutGet` and `getWithoutSet` behavior |
| [`array-callback-return`](https://eslint.org/docs/latest/rules/array-callback-return) | Implemented for optional `allowImplicit`, `checkForEach`, and `allowVoid` behavior |
| [`block-scoped-var`](https://eslint.org/docs/latest/rules/block-scoped-var) | Implemented |
| [`capitalized-comments`](https://eslint.org/docs/latest/rules/capitalized-comments) | Implemented for `always`, optional `never`, and optional `ignoreInlineComments` behavior |
| [`consistent-return`](https://eslint.org/docs/latest/rules/consistent-return) | Implemented for mixed explicit value/bare returns and value-returning functions that can fall through |
| [`constructor-super`](https://eslint.org/docs/latest/rules/constructor-super) | Implemented |
| [`curly`](https://eslint.org/docs/latest/rules/curly) | Implemented |
| [`default-case`](https://eslint.org/docs/latest/rules/default-case) | Implemented |
| [`default-case-last`](https://eslint.org/docs/latest/rules/default-case-last) | Implemented |
| [`default-param-last`](https://eslint.org/docs/latest/rules/default-param-last) | Implemented |
| [`dot-notation`](https://eslint.org/docs/latest/rules/dot-notation) | Implemented |
| [`eol-last`](https://eslint.org/docs/latest/rules/eol-last) | Implemented |
| [`eqeqeq`](https://eslint.org/docs/latest/rules/eqeqeq) | Implemented |
| [`for-direction`](https://eslint.org/docs/latest/rules/for-direction) | Implemented |
| [`func-name-matching`](https://eslint.org/docs/latest/rules/func-name-matching) | Implemented for `always` and optional `never` behavior |
| [`func-names`](https://eslint.org/docs/latest/rules/func-names) | Implemented for `always` and optional `as-needed` options |
| [`getter-return`](https://eslint.org/docs/latest/rules/getter-return) | Implemented |
| [`grouped-accessor-pairs`](https://eslint.org/docs/latest/rules/grouped-accessor-pairs) | Implemented for `anyOrder`, `getBeforeSet`, and `setBeforeGet` options |
| [`guard-for-in`](https://eslint.org/docs/latest/rules/guard-for-in) | Implemented |
| [`linebreak-style`](https://eslint.org/docs/latest/rules/linebreak-style) | Implemented |
| [`logical-assignment-operators`](https://eslint.org/docs/latest/rules/logical-assignment-operators) | Implemented for `always`, optional `never`, and optional `enforceForIfStatements: true` behavior |
| [`new-cap`](https://eslint.org/docs/latest/rules/new-cap) | Implemented |
| [`new-parens`](https://eslint.org/docs/latest/rules/new-parens) | Implemented |
| [`no-alert`](https://eslint.org/docs/latest/rules/no-alert) | Implemented |
| [`no-array-constructor`](https://eslint.org/docs/latest/rules/no-array-constructor) | Implemented |
| [`no-async-promise-executor`](https://eslint.org/docs/latest/rules/no-async-promise-executor) | Implemented |
| [`no-await-in-loop`](https://eslint.org/docs/latest/rules/no-await-in-loop) | Implemented |
| [`no-bitwise`](https://eslint.org/docs/latest/rules/no-bitwise) | Implemented |
| [`no-buffer-constructor`](https://eslint.org/docs/latest/rules/no-buffer-constructor) | Implemented |
| [`no-caller`](https://eslint.org/docs/latest/rules/no-caller) | Implemented |
| [`no-case-declarations`](https://eslint.org/docs/latest/rules/no-case-declarations) | Implemented |
| [`no-class-assign`](https://eslint.org/docs/latest/rules/no-class-assign) | Implemented |
| [`no-confusing-arrow`](https://eslint.org/docs/latest/rules/no-confusing-arrow) | Implemented for `allowParens: true` and `allowParens: false` |
| [`no-comma-operator`](https://eslint.org/docs/latest/rules/no-comma-operator) | Implemented |
| [`no-compare-neg-zero`](https://eslint.org/docs/latest/rules/no-compare-neg-zero) | Implemented |
| [`no-cond-assign`](https://eslint.org/docs/latest/rules/no-cond-assign) | Implemented |
| [`no-console`](https://eslint.org/docs/latest/rules/no-console) | Implemented with `allow` support for known console methods |
| [`no-const-assign`](https://eslint.org/docs/latest/rules/no-const-assign) | Implemented |
| [`no-constant-condition`](https://eslint.org/docs/latest/rules/no-constant-condition) | Implemented |
| [`no-constructor-return`](https://eslint.org/docs/latest/rules/no-constructor-return) | Implemented |
| [`no-continue`](https://eslint.org/docs/latest/rules/no-continue) | Implemented |
| [`no-control-regex`](https://eslint.org/docs/latest/rules/no-control-regex) | Implemented |
| [`no-debugger`](https://eslint.org/docs/latest/rules/no-debugger) | Implemented |
| [`no-delete-var`](https://eslint.org/docs/latest/rules/no-delete-var) | Implemented |
| [`no-div-regex`](https://eslint.org/docs/latest/rules/no-div-regex) | Implemented |
| [`no-dupe-args`](https://eslint.org/docs/latest/rules/no-dupe-args) | Implemented |
| [`no-dupe-class-members`](https://eslint.org/docs/latest/rules/no-dupe-class-members) | Implemented |
| [`no-dupe-else-if`](https://eslint.org/docs/latest/rules/no-dupe-else-if) | Implemented |
| [`no-dupe-keys`](https://eslint.org/docs/latest/rules/no-dupe-keys) | Implemented |
| [`no-duplicate-case`](https://eslint.org/docs/latest/rules/no-duplicate-case) | Implemented |
| [`no-duplicate-imports`](https://eslint.org/docs/latest/rules/no-duplicate-imports) | Implemented |
| [`no-else-return`](https://eslint.org/docs/latest/rules/no-else-return) | Implemented |
| [`no-empty`](https://eslint.org/docs/latest/rules/no-empty) | Implemented with optional `allowEmptyCatch` behavior |
| [`no-empty-block-statements`](https://eslint.org/docs/latest/rules/no-empty-block-statements) | Implemented |
| [`no-empty-character-class`](https://eslint.org/docs/latest/rules/no-empty-character-class) | Implemented |
| [`no-empty-function`](https://eslint.org/docs/latest/rules/no-empty-function) | Implemented with partial `allow` behavior for functions, arrow functions, methods, and constructors |
| [`no-empty-pattern`](https://eslint.org/docs/latest/rules/no-empty-pattern) | Implemented |
| [`no-empty-static-block`](https://eslint.org/docs/latest/rules/no-empty-static-block) | Implemented |
| [`no-eq-null`](https://eslint.org/docs/latest/rules/no-eq-null) | Implemented |
| [`no-eval`](https://eslint.org/docs/latest/rules/no-eval) | Implemented |
| [`no-ex-assign`](https://eslint.org/docs/latest/rules/no-ex-assign) | Implemented |
| [`no-extend-native`](https://eslint.org/docs/latest/rules/no-extend-native) | Implemented |
| [`no-extra-bind`](https://eslint.org/docs/latest/rules/no-extra-bind) | Implemented |
| [`no-extra-boolean-cast`](https://eslint.org/docs/latest/rules/no-extra-boolean-cast) | Implemented |
| [`no-extra-label`](https://eslint.org/docs/latest/rules/no-extra-label) | Implemented |
| [`no-extra-semi`](https://eslint.org/docs/latest/rules/no-extra-semi) | Implemented |
| [`no-fallthrough`](https://eslint.org/docs/latest/rules/no-fallthrough) | Implemented with optional `allowEmptyCase` behavior |
| [`no-floating-decimal`](https://eslint.org/docs/latest/rules/no-floating-decimal) | Implemented |
| [`no-for-in`](https://eslint.org/docs/latest/rules/no-for-in) | Implemented |
| [`no-func-assign`](https://eslint.org/docs/latest/rules/no-func-assign) | Implemented |
| [`no-global-assign`](https://eslint.org/docs/latest/rules/no-global-assign) | Implemented |
| [`no-global-is-finite`](https://eslint.org/docs/latest/rules/no-global-is-finite) | Implemented |
| [`no-global-is-nan`](https://eslint.org/docs/latest/rules/no-global-is-nan) | Implemented |
| [`no-implicit-coercion`](https://eslint.org/docs/latest/rules/no-implicit-coercion) | Implemented with optional `boolean`, `number`, and `string` category behavior |
| [`no-implied-eval`](https://eslint.org/docs/latest/rules/no-implied-eval) | Implemented |
| [`no-import-assign`](https://eslint.org/docs/latest/rules/no-import-assign) | Implemented |
| [`no-inline-comments`](https://eslint.org/docs/latest/rules/no-inline-comments) | Implemented |
| [`no-inner-declarations`](https://eslint.org/docs/latest/rules/no-inner-declarations) | Implemented |
| [`no-invalid-regexp`](https://eslint.org/docs/latest/rules/no-invalid-regexp) | Implemented |
| [`no-irregular-whitespace`](https://eslint.org/docs/latest/rules/no-irregular-whitespace) | Implemented |
| [`no-iterator`](https://eslint.org/docs/latest/rules/no-iterator) | Implemented |
| [`no-label-var`](https://eslint.org/docs/latest/rules/no-label-var) | Implemented |
| [`no-labels`](https://eslint.org/docs/latest/rules/no-labels) | Implemented |
| [`no-lone-blocks`](https://eslint.org/docs/latest/rules/no-lone-blocks) | Implemented |
| [`no-lonely-if`](https://eslint.org/docs/latest/rules/no-lonely-if) | Implemented |
| [`no-loop-func`](https://eslint.org/docs/latest/rules/no-loop-func) | Implemented |
| [`no-loss-of-precision`](https://eslint.org/docs/latest/rules/no-loss-of-precision) | Implemented |
| [`no-mixed-spaces-and-tabs`](https://eslint.org/docs/latest/rules/no-mixed-spaces-and-tabs) | Implemented |
| [`no-misleading-character-class`](https://eslint.org/docs/latest/rules/no-misleading-character-class) | Implemented |
| [`no-multi-assign`](https://eslint.org/docs/latest/rules/no-multi-assign) | Implemented |
| [`no-multi-spaces`](https://eslint.org/docs/latest/rules/no-multi-spaces) | Implemented |
| [`no-multi-str`](https://eslint.org/docs/latest/rules/no-multi-str) | Implemented |
| [`no-multiple-empty-lines`](https://eslint.org/docs/latest/rules/no-multiple-empty-lines) | Implemented |
| [`no-negated-condition`](https://eslint.org/docs/latest/rules/no-negated-condition) | Implemented |
| [`no-nested-ternary`](https://eslint.org/docs/latest/rules/no-nested-ternary) | Implemented |
| [`no-new`](https://eslint.org/docs/latest/rules/no-new) | Implemented |
| [`no-new-func`](https://eslint.org/docs/latest/rules/no-new-func) | Implemented |
| [`no-new-native-nonconstructor`](https://eslint.org/docs/latest/rules/no-new-native-nonconstructor) | Implemented |
| [`no-new-object`](https://eslint.org/docs/latest/rules/no-new-object) | Implemented |
| [`no-new-require`](https://eslint.org/docs/latest/rules/no-new-require) | Implemented |
| [`no-new-symbol`](https://eslint.org/docs/latest/rules/no-new-symbol) | Implemented |
| [`no-new-wrappers`](https://eslint.org/docs/latest/rules/no-new-wrappers) | Implemented |
| [`no-nonoctal-decimal-escape`](https://eslint.org/docs/latest/rules/no-nonoctal-decimal-escape) | Implemented |
| [`no-obj-calls`](https://eslint.org/docs/latest/rules/no-obj-calls) | Implemented |
| [`no-object-constructor`](https://eslint.org/docs/latest/rules/no-object-constructor) | Implemented |
| [`no-octal`](https://eslint.org/docs/latest/rules/no-octal) | Implemented |
| [`no-octal-escape`](https://eslint.org/docs/latest/rules/no-octal-escape) | Implemented |
| [`no-param-reassign`](https://eslint.org/docs/latest/rules/no-param-reassign) | Implemented with optional `props` behavior |
| [`no-path-concat`](https://eslint.org/docs/latest/rules/no-path-concat) | Implemented |
| [`no-plusplus`](https://eslint.org/docs/latest/rules/no-plusplus) | Implemented with optional `allowForLoopAfterthoughts` behavior |
| [`no-process-env`](https://eslint.org/docs/latest/rules/no-process-env) | Implemented |
| [`no-process-exit`](https://eslint.org/docs/latest/rules/no-process-exit) | Implemented |
| [`no-promise-executor-return`](https://eslint.org/docs/latest/rules/no-promise-executor-return) | Implemented |
| [`no-proto`](https://eslint.org/docs/latest/rules/no-proto) | Implemented |
| [`no-prototype-builtins`](https://eslint.org/docs/latest/rules/no-prototype-builtins) | Implemented |
| [`no-regex-spaces`](https://eslint.org/docs/latest/rules/no-regex-spaces) | Implemented |
| [`no-return-assign`](https://eslint.org/docs/latest/rules/no-return-assign) | Implemented for `except-parens` and optional `always` behavior |
| [`no-return-await`](https://eslint.org/docs/latest/rules/no-return-await) | Implemented |
| [`no-script-url`](https://eslint.org/docs/latest/rules/no-script-url) | Implemented |
| [`no-self-assign`](https://eslint.org/docs/latest/rules/no-self-assign) | Implemented |
| [`no-self-compare`](https://eslint.org/docs/latest/rules/no-self-compare) | Implemented |
| [`no-sequences`](https://eslint.org/docs/latest/rules/no-sequences) | Implemented |
| [`no-setter-return`](https://eslint.org/docs/latest/rules/no-setter-return) | Implemented |
| [`no-shadow-restricted-names`](https://eslint.org/docs/latest/rules/no-shadow-restricted-names) | Implemented |
| [`no-sparse-arrays`](https://eslint.org/docs/latest/rules/no-sparse-arrays) | Implemented |
| [`no-tabs`](https://eslint.org/docs/latest/rules/no-tabs) | Implemented |
| [`no-template-curly-in-string`](https://eslint.org/docs/latest/rules/no-template-curly-in-string) | Implemented |
| [`no-ternary`](https://eslint.org/docs/latest/rules/no-ternary) | Implemented |
| [`no-this-before-super`](https://eslint.org/docs/latest/rules/no-this-before-super) | Implemented |
| [`no-throw-literal`](https://eslint.org/docs/latest/rules/no-throw-literal) | Implemented |
| [`no-trailing-spaces`](https://eslint.org/docs/latest/rules/no-trailing-spaces) | Implemented |
| [`no-undef`](https://eslint.org/docs/latest/rules/no-undef) | Implemented |
| [`no-undef-init`](https://eslint.org/docs/latest/rules/no-undef-init) | Implemented |
| [`no-underscore-dangle`](https://eslint.org/docs/latest/rules/no-underscore-dangle) | Implemented for default declaration/member-property checks and optional `allowAfterThis`, `allowAfterSuper`, `allowAfterThisConstructor`, `allowFunctionParams`, `allowInArrayDestructuring`, `allowInObjectDestructuring`, `enforceInMethodNames`, and `enforceInClassFields` behavior |
| [`no-undefined`](https://eslint.org/docs/latest/rules/no-undefined) | Implemented for identifier references and binding names |
| [`no-unneeded-ternary`](https://eslint.org/docs/latest/rules/no-unneeded-ternary) | Implemented |
| [`no-unreachable`](https://eslint.org/docs/latest/rules/no-unreachable) | Implemented |
| [`no-unsafe-finally`](https://eslint.org/docs/latest/rules/no-unsafe-finally) | Implemented |
| [`no-unsafe-negation`](https://eslint.org/docs/latest/rules/no-unsafe-negation) | Implemented |
| [`no-unused-expressions`](https://eslint.org/docs/latest/rules/no-unused-expressions) | Implemented |
| [`no-unused-labels`](https://eslint.org/docs/latest/rules/no-unused-labels) | Implemented |
| [`no-unused-vars`](https://eslint.org/docs/latest/rules/no-unused-vars) | Implemented |
| [`no-useless-call`](https://eslint.org/docs/latest/rules/no-useless-call) | Implemented |
| [`no-useless-catch`](https://eslint.org/docs/latest/rules/no-useless-catch) | Implemented |
| [`no-useless-computed-key`](https://eslint.org/docs/latest/rules/no-useless-computed-key) | Implemented with optional `enforceForClassMembers` behavior |
| [`no-useless-concat`](https://eslint.org/docs/latest/rules/no-useless-concat) | Implemented |
| [`no-useless-constructor`](https://eslint.org/docs/latest/rules/no-useless-constructor) | Implemented |
| [`no-useless-escape`](https://eslint.org/docs/latest/rules/no-useless-escape) | Implemented |
| [`no-useless-rename`](https://eslint.org/docs/latest/rules/no-useless-rename) | Implemented |
| [`no-useless-return`](https://eslint.org/docs/latest/rules/no-useless-return) | Implemented |
| [`no-var`](https://eslint.org/docs/latest/rules/no-var) | Implemented |
| [`no-void`](https://eslint.org/docs/latest/rules/no-void) | Implemented with optional `allowAsStatement` behavior |
| [`no-warning-comments`](https://eslint.org/docs/latest/rules/no-warning-comments) | Implemented for default `location: start`, optional `location: anywhere`, and common `decoration` behavior |
| [`no-with`](https://eslint.org/docs/latest/rules/no-with) | Implemented |
| [`object-shorthand`](https://eslint.org/docs/latest/rules/object-shorthand) | Implemented |
| [`one-var`](https://eslint.org/docs/latest/rules/one-var) | Implemented for fishlint's `never` configuration |
| [`operator-assignment`](https://eslint.org/docs/latest/rules/operator-assignment) | Implemented |
| [`prefer-const`](https://eslint.org/docs/latest/rules/prefer-const) | Implemented for optional `destructuring: any` and `destructuring: all` behavior; `ignoreReadBeforeAssign: true` |
| [`prefer-destructuring`](https://eslint.org/docs/latest/rules/prefer-destructuring) | Implemented for object and array variable declarators and assignment expressions |
| [`prefer-exponentiation-operator`](https://eslint.org/docs/latest/rules/prefer-exponentiation-operator) | Implemented |
| [`prefer-numeric-literals`](https://eslint.org/docs/latest/rules/prefer-numeric-literals) | Implemented for static string and template `parseInt` calls with binary, octal, or hexadecimal radix |
| [`prefer-object-has-own`](https://eslint.org/docs/latest/rules/prefer-object-has-own) | Implemented |
| [`prefer-object-spread`](https://eslint.org/docs/latest/rules/prefer-object-spread) | Implemented for `Object.assign` calls with a new object literal target |
| [`prefer-promise-reject-errors`](https://eslint.org/docs/latest/rules/prefer-promise-reject-errors) | Implemented |
| [`prefer-regex-literals`](https://eslint.org/docs/latest/rules/prefer-regex-literals) | Implemented |
| [`prefer-rest-params`](https://eslint.org/docs/latest/rules/prefer-rest-params) | Implemented |
| [`prefer-spread`](https://eslint.org/docs/latest/rules/prefer-spread) | Implemented |
| [`prefer-template`](https://eslint.org/docs/latest/rules/prefer-template) | Implemented |
| [`radix`](https://eslint.org/docs/latest/rules/radix) | Implemented |
| [`require-await`](https://eslint.org/docs/latest/rules/require-await) | Implemented |
| [`require-atomic-updates`](https://eslint.org/docs/latest/rules/require-atomic-updates) | Implemented |
| [`require-yield`](https://eslint.org/docs/latest/rules/require-yield) | Implemented |
| [`spaced-comment`](https://eslint.org/docs/latest/rules/spaced-comment) | Implemented |
| [`symbol-description`](https://eslint.org/docs/latest/rules/symbol-description) | Implemented |
| [`unicode-bom`](https://eslint.org/docs/latest/rules/unicode-bom) | Implemented |
| [`use-isnan`](https://eslint.org/docs/latest/rules/use-isnan) | Implemented |
| [`valid-typeof`](https://eslint.org/docs/latest/rules/valid-typeof) | Implemented |
| [`vars-on-top`](https://eslint.org/docs/latest/rules/vars-on-top) | Implemented |
| [`wrap-iife`](https://eslint.org/docs/latest/rules/wrap-iife) | Implemented for `outside`, `inside`, and `any` options |
| [`yoda`](https://eslint.org/docs/latest/rules/yoda) | Implemented |

## Import plugin rules

| Rule | Status |
| --- | --- |
| [`import/default`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/default.md) | Implemented for relative imports resolved with fishlint's configured extensions |
| [`import/export`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/export.md) | Implemented for duplicate local exports and relative `export *` |
| [`import/first`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/first.md) | Implemented |
| [`import/named`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/named.md) | Implemented for relative imports resolved with fishlint's configured extensions |
| [`import/namespace`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/namespace.md) | Implemented for relative namespace imports resolved with fishlint's configured extensions |
| [`import/newline-after-import`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/newline-after-import.md) | Implemented for fishlint's default `count: 1` behavior |
| [`import/no-amd`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/no-amd.md) | Implemented |
| [`import/no-cycle`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/no-cycle.md) | Implemented for relative imports and re-exports resolved with fishlint's configured extensions |
| [`import/no-duplicates`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/no-duplicates.md) | Implemented |
| [`import/no-named-as-default`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/no-named-as-default.md) | Implemented for relative imports resolved with fishlint's configured extensions |
| [`import/no-named-as-default-member`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/no-named-as-default-member.md) | Implemented for relative imports resolved with fishlint's configured extensions |
| [`import/no-unresolved`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/no-unresolved.md) | Implemented for fishlint's node resolver extensions and `smallfish:`/`minifish:` ignores |
| [`import/no-self-import`](https://github.com/import-js/eslint-plugin-import/blob/main/docs/rules/no-self-import.md) | Implemented for relative imports resolved with fishlint's configured extensions |

## JSX a11y rules

| Rule | Status |
| --- | --- |
| [`jsx-a11y/aria-props`](https://github.com/jsx-eslint/eslint-plugin-jsx-a11y/blob/main/docs/rules/aria-props.md) | Implemented |
| [`jsx-a11y/iframe-has-title`](https://github.com/jsx-eslint/eslint-plugin-jsx-a11y/blob/main/docs/rules/iframe-has-title.md) | Implemented |
| [`jsx-a11y/img-redundant-alt`](https://github.com/jsx-eslint/eslint-plugin-jsx-a11y/blob/main/docs/rules/img-redundant-alt.md) | Implemented |
| [`jsx-a11y/no-access-key`](https://github.com/jsx-eslint/eslint-plugin-jsx-a11y/blob/main/docs/rules/no-access-key.md) | Implemented |

## Parser diagnostics

`parser-semantic-errors` reports parse diagnostics from Yuku, including semantic early errors by default. It is not an ESLint rule and therefore does not have a corresponding ESLint rule page.

## React rules

| Rule | Status |
| --- | --- |
| [`react/jsx-boolean-value`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/jsx-boolean-value.md) | Implemented for fishlint's `never` configuration |
| [`react/jsx-no-comment-textnodes`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/jsx-no-comment-textnodes.md) | Implemented |
| [`react/jsx-no-duplicate-props`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/jsx-no-duplicate-props.md) | Implemented for fishlint's `ignoreCase: true` configuration |
| [`react/jsx-no-target-blank`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/jsx-no-target-blank.md) | Implemented for eslint-plugin-react's default link configuration |
| [`react/jsx-pascal-case`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/jsx-pascal-case.md) | Implemented for fishlint's `allowAllCaps: true, ignore: []` configuration |
| [`react/no-danger`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/no-danger.md) | Implemented |
| [`react/no-find-dom-node`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/no-find-dom-node.md) | Implemented |
| [`react/no-is-mounted`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/no-is-mounted.md) | Implemented |
| [`react/no-render-return-value`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/no-render-return-value.md) | Implemented for eslint-plugin-react's default/latest React version behavior |
| [`react/no-unescaped-entities`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/no-unescaped-entities.md) | Implemented for eslint-plugin-react's default entity set |
| [`react/no-unused-prop-types`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/no-unused-prop-types.md) | Implemented for fishlint's `customValidators: [], skipShapeProps: true` configuration |
| [`react/prop-types`](https://github.com/jsx-eslint/eslint-plugin-react/blob/master/docs/rules/prop-types.md) | Implemented for fishlint's `ignore: [], customValidators: [], skipUndeclared: false` configuration |

## React Hooks rules

| Rule | Status |
| --- | --- |
| [`react-hooks/rules-of-hooks`](https://legacy.reactjs.org/docs/hooks-rules.html) | Implemented for top-level, ordinary function, class method, callback, conditional branch, and loop checks |

## TypeScript ESLint rules

| Rule | Status |
| --- | --- |
| [`@typescript-eslint/adjacent-overload-signatures`](https://typescript-eslint.io/rules/adjacent-overload-signatures/) | Implemented |
| [`@typescript-eslint/array-type`](https://typescript-eslint.io/rules/array-type/) | Implemented for fishlint's `array-simple` configuration |
| [`@typescript-eslint/ban-ts-comment`](https://typescript-eslint.io/rules/ban-ts-comment/) | Implemented for fishlint's `allow-with-description` configuration |
| [`@typescript-eslint/ban-tslint-comment`](https://typescript-eslint.io/rules/ban-tslint-comment/) | Implemented |
| [`@typescript-eslint/ban-types`](https://typescript-eslint.io/rules/ban-types/) | Implemented for fishlint's `types: { '{}': false, object: false }, extendDefaults: true` configuration |
| [`@typescript-eslint/class-literal-property-style`](https://typescript-eslint.io/rules/class-literal-property-style/) | Implemented for fishlint's `fields` configuration |
| [`@typescript-eslint/consistent-type-assertions`](https://typescript-eslint.io/rules/consistent-type-assertions/) | Implemented for fishlint's `assertionStyle: as, objectLiteralTypeAssertions: never` configuration |
| [`@typescript-eslint/consistent-type-definitions`](https://typescript-eslint.io/rules/consistent-type-definitions/) | Implemented for fishlint's `interface` configuration |
| [`@typescript-eslint/dot-notation`](https://typescript-eslint.io/rules/dot-notation/) | Implemented |
| [`@typescript-eslint/explicit-member-accessibility`](https://typescript-eslint.io/rules/explicit-member-accessibility/) | Implemented for fishlint's `no-public` configuration |
| [`@typescript-eslint/member-ordering`](https://typescript-eslint.io/rules/member-ordering/) | Implemented for fishlint's default class member ordering |
| [`@typescript-eslint/method-signature-style`](https://typescript-eslint.io/rules/method-signature-style/) | Implemented for fishlint's `property` configuration |
| [`@typescript-eslint/no-array-constructor`](https://typescript-eslint.io/rules/no-array-constructor/) | Implemented |
| [`@typescript-eslint/no-confusing-non-null-assertion`](https://typescript-eslint.io/rules/no-confusing-non-null-assertion/) | Implemented |
| [`@typescript-eslint/no-dupe-class-members`](https://typescript-eslint.io/rules/no-dupe-class-members/) | Implemented |
| [`@typescript-eslint/no-empty-function`](https://typescript-eslint.io/rules/no-empty-function/) | Implemented |
| [`@typescript-eslint/no-empty-interface`](https://typescript-eslint.io/rules/no-empty-interface/) | Implemented |
| [`@typescript-eslint/no-duplicate-enum-values`](https://typescript-eslint.io/rules/no-duplicate-enum-values/) | Implemented |
| [`@typescript-eslint/no-extra-semi`](https://typescript-eslint.io/rules/no-extra-semi/) | Implemented |
| [`@typescript-eslint/no-extra-non-null-assertion`](https://typescript-eslint.io/rules/no-extra-non-null-assertion/) | Implemented |
| [`@typescript-eslint/no-inferrable-types`](https://typescript-eslint.io/rules/no-inferrable-types/) | Implemented |
| [`@typescript-eslint/no-invalid-void-type`](https://typescript-eslint.io/rules/no-invalid-void-type/) | Implemented |
| [`@typescript-eslint/no-loss-of-precision`](https://typescript-eslint.io/rules/no-loss-of-precision/) | Implemented |
| [`@typescript-eslint/no-misused-new`](https://typescript-eslint.io/rules/no-misused-new/) | Implemented |
| [`@typescript-eslint/no-namespace`](https://typescript-eslint.io/rules/no-namespace/) | Implemented for fishlint's `allowDeclarations: true, allowDefinitionFiles: true` configuration |
| [`@typescript-eslint/no-non-null-asserted-optional-chain`](https://typescript-eslint.io/rules/no-non-null-asserted-optional-chain/) | Implemented |
| [`@typescript-eslint/no-redeclare`](https://typescript-eslint.io/rules/no-redeclare/) | Implemented |
| [`@typescript-eslint/no-require-imports`](https://typescript-eslint.io/rules/no-require-imports/) | Implemented |
| [`@typescript-eslint/no-shadow`](https://typescript-eslint.io/rules/no-shadow/) | Implemented |
| [`@typescript-eslint/no-this-alias`](https://typescript-eslint.io/rules/no-this-alias/) | Implemented for fishlint's `allowedNames: ['self']` configuration |
| [`@typescript-eslint/no-unsafe-declaration-merging`](https://typescript-eslint.io/rules/no-unsafe-declaration-merging/) | Implemented |
| [`@typescript-eslint/triple-slash-reference`](https://typescript-eslint.io/rules/triple-slash-reference/) | Implemented for fishlint's `path: never, types: always, lib: always` configuration |
| [`@typescript-eslint/typedef`](https://typescript-eslint.io/rules/typedef/) | Implemented for fishlint's `propertyDeclaration: true` configuration |
| [`@typescript-eslint/unified-signatures`](https://typescript-eslint.io/rules/unified-signatures/) | Implemented |
| [`@typescript-eslint/no-unnecessary-parameter-property-assignment`](https://typescript-eslint.io/rules/no-unnecessary-parameter-property-assignment/) | Implemented for constructor assignments in the constructor body |
| [`@typescript-eslint/no-unnecessary-type-constraint`](https://typescript-eslint.io/rules/no-unnecessary-type-constraint/) | Implemented |
| [`@typescript-eslint/no-useless-constructor`](https://typescript-eslint.io/rules/no-useless-constructor/) | Implemented |
| [`@typescript-eslint/no-useless-empty-export`](https://typescript-eslint.io/rules/no-useless-empty-export/) | Implemented |
| [`@typescript-eslint/no-unused-expressions`](https://typescript-eslint.io/rules/no-unused-expressions/) | Implemented for fishlint's `allowShortCircuit: true, allowTernary: true, allowTaggedTemplates: true` configuration |
| [`@typescript-eslint/no-unused-vars`](https://typescript-eslint.io/rules/no-unused-vars/) | Implemented for fishlint's `args: after-used, ignoreRestSiblings: true` configuration |
| [`@typescript-eslint/no-use-before-define`](https://typescript-eslint.io/rules/no-use-before-define/) | Implemented for fishlint's `functions: false, classes: true` configuration |
| [`@typescript-eslint/no-var-requires`](https://typescript-eslint.io/rules/no-var-requires/) | Implemented |
| [`@typescript-eslint/no-wrapper-object-types`](https://typescript-eslint.io/rules/no-wrapper-object-types/) | Implemented |
| [`@typescript-eslint/prefer-as-const`](https://typescript-eslint.io/rules/prefer-as-const/) | Implemented |
| [`@typescript-eslint/prefer-namespace-keyword`](https://typescript-eslint.io/rules/prefer-namespace-keyword/) | Implemented |
| [`@typescript-eslint/restrict-plus-operands`](https://typescript-eslint.io/rules/restrict-plus-operands/) | Implemented for primitive literals and explicit primitive annotations |
