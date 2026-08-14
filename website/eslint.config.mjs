// vivobody website ESLint configuration
//
// Enforces the repository naming standard (see ../AGENTS.md and
// ../engineering/quality.md) for every script the site ships, including
// <script> blocks and frontmatter inside .astro components: camelCase for
// variables, functions, and parameters; PascalCase for classes and other
// type-like declarations. Run with `npm run lint`.

import astro from "eslint-plugin-astro";
import tseslint from "typescript-eslint";

const namingConvention = [
  "error",
  {
    selector: "variable",
    format: ["camelCase", "UPPER_CASE", "PascalCase"],
    leadingUnderscore: "allow",
  },
  {
    selector: "parameter",
    format: ["camelCase"],
    leadingUnderscore: "allow",
  },
  { selector: "function", format: ["camelCase"] },
  { selector: "typeLike", format: ["PascalCase"] },
  { selector: "enumMember", format: ["camelCase", "PascalCase", "UPPER_CASE"] },
];

export default tseslint.config(
  {
    ignores: ["dist/", ".astro/", "node_modules/", "public/"],
  },
  ...astro.configs["flat/recommended"],
  {
    files: ["**/*.{js,mjs,cjs,ts}"],
    languageOptions: {
      parser: tseslint.parser,
    },
    plugins: {
      "@typescript-eslint": tseslint.plugin,
    },
    rules: {
      "@typescript-eslint/naming-convention": namingConvention,
    },
  },
  {
    // .astro files keep the astro-eslint-parser from the recommended config;
    // it forwards frontmatter and <script> blocks to the TypeScript parser,
    // so the same naming rules apply without re-declaring the parser here.
    files: ["**/*.astro"],
    plugins: {
      "@typescript-eslint": tseslint.plugin,
    },
    rules: {
      "@typescript-eslint/naming-convention": namingConvention,
    },
  },
);
