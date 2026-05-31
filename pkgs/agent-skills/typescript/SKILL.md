---
name: typescript
description: |
  Full TypeScript project setup and writing conventions using Bun runtime. Use this skill whenever the user:
  - Wants to init a new TypeScript project from scratch ("init project", "สร้าง project", "setup typescript")
  - Asks to add tooling to an existing TS/JS project (linting, testing, git hooks, logging, etc.)
  - Is writing TypeScript code that should follow a specific stack (Bun, Pino, Zod, Got, t3-env, Vitest, Playwright)
  - Mentions any of: bun, pino, zod, got, t3-env, commitlint, standard-version, lint-staged, husky, EditorConfig, path alias with @
  - Wants to add pre-commit hooks, changelog generation, or commit convention enforcement
  - Asks how to structure imports, logging, env vars, API calls, or validation in a TypeScript project
  - Has an existing project and wants to migrate / add missing pieces of this stack
  Always consult this skill before writing any TypeScript code, config files, or setup scripts in this stack — even for "just a quick script".
---

# TypeScript + Bun Stack Skill

**Stack at a glance:**

| Concern | Tool |
|---|---|
| Runtime | Bun (only) |
| Logger | Pino + pino-pretty |
| Lint | ESLint + Prettier |
| Type validation | Zod (only) |
| HTTP client | got + http-errors |
| Env management | t3-oss/t3-env |
| Unit tests | Vitest |
| E2E tests | Playwright |
| Path alias | tsconfig paths, `@/` prefix only |
| Editor safety | EditorConfig |
| Pre-commit | Husky + lint-staged |
| Commit style | Commitlint (conventional commits) |
| Changelog | standard-version |

---

## Decision Tree: What to do first

```
User request
    │
    ├─ "init" / "สร้าง" / new project? ──► Section A: Project Initialisation
    │
    ├─ Existing project, missing pieces? ──► Section B: Adopt into Existing Project
    │
    └─ Writing code in this stack? ──────► Section C: Code Writing Conventions
```

---

## Section A — Project Initialisation

### A1. Check & Install Bun

```bash
# Check if bun is installed
if ! command -v bun &> /dev/null; then
  echo "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
  # Reload shell env
  source ~/.bashrc || source ~/.zshrc || true
fi

bun --version  # confirm
```

### A2. Scaffold the project

```bash
mkdir <project-name> && cd <project-name>
bun init -y
```

This creates `package.json`, `tsconfig.json`, and `index.ts`. **Overwrite** `tsconfig.json` completely — the Bun default is too permissive.

### A3. Required `tsconfig.json`

```jsonc
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*", "tests/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### A4. Required `.editorconfig`

```ini
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
```

### A5. Install all dependencies

Run in this order (production deps first, then dev):

```bash
# ── Production ──────────────────────────────────────────────────
bun add pino got http-errors @t3-oss/env-core zod

# ── Dev: TypeScript types ───────────────────────────────────────
bun add -d @types/bun @types/node @types/http-errors

# ── Dev: Logger pretty-print (dev only) ────────────────────────
bun add -d pino-pretty

# ── Dev: Lint & Format ─────────────────────────────────────────
bun add -d eslint @typescript-eslint/eslint-plugin @typescript-eslint/parser prettier eslint-config-prettier eslint-plugin-prettier

# ── Dev: Testing ───────────────────────────────────────────────
bun add -d vitest @vitest/coverage-v8
bun add -d @playwright/test

# ── Dev: Git hooks & commit convention ─────────────────────────
bun add -d husky lint-staged @commitlint/cli @commitlint/config-conventional

# ── Dev: Changelog ─────────────────────────────────────────────
bun add -d standard-version
```

### A6. ESLint config (`eslint.config.mjs`)

```js
// eslint.config.mjs  (flat config, ESLint v9+)
import tsPlugin from "@typescript-eslint/eslint-plugin";
import tsParser from "@typescript-eslint/parser";
import prettierPlugin from "eslint-plugin-prettier";
import prettierConfig from "eslint-config-prettier";

export default [
  {
    ignores: ["dist/**", "node_modules/**", "coverage/**", "playwright-report/**"],
  },
  {
    files: ["**/*.ts", "**/*.tsx"],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        project: "./tsconfig.json",
      },
    },
    plugins: {
      "@typescript-eslint": tsPlugin,
      prettier: prettierPlugin,
    },
    rules: {
      ...tsPlugin.configs["recommended"].rules,
      ...tsPlugin.configs["recommended-requiring-type-checking"].rules,
      ...prettierConfig.rules,
      "prettier/prettier": "error",
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "@typescript-eslint/consistent-type-imports": "error",
      "@typescript-eslint/no-explicit-any": "error",
    },
  },
];
```

### A7. Prettier config (`.prettierrc`)

```json
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "all",
  "printWidth": 100,
  "arrowParens": "always",
  "endOfLine": "lf"
}
```

`.prettierignore`:
```
dist/
node_modules/
coverage/
playwright-report/
CHANGELOG.md
```

### A8. Commitlint config (`commitlint.config.ts`)

```ts
import type { UserConfig } from "@commitlint/types";

const config: UserConfig = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [
      2,
      "always",
      ["feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert"],
    ],
    "subject-case": [2, "always", "lower-case"],
    "subject-max-length": [2, "always", 72],
  },
};

export default config;
```

### A9. standard-version config (`.versionrc.json`)

```json
{
  "types": [
    { "type": "feat",     "section": "✨ Features" },
    { "type": "fix",      "section": "🐛 Bug Fixes" },
    { "type": "perf",     "section": "⚡ Performance" },
    { "type": "refactor", "section": "♻️  Refactors" },
    { "type": "docs",     "section": "📝 Documentation" },
    { "type": "test",     "section": "🧪 Tests" },
    { "type": "build",    "section": "🏗️  Build System" },
    { "type": "ci",       "section": "👷 CI" },
    { "type": "chore",    "hidden": true }
  ],
  "commitUrlFormat": "{{host}}/{{owner}}/{{repository}}/commit/{{hash}}",
  "compareUrlFormat": "{{host}}/{{owner}}/{{repository}}/compare/{{previousTag}}...{{currentTag}}"
}
```

### A10. Husky + lint-staged setup

```bash
# Initialise Husky
bun run husky init
```

`.husky/pre-commit`:
```sh
#!/usr/bin/env sh
bun run lint-staged
```

`.husky/commit-msg`:
```sh
#!/usr/bin/env sh
bun run commitlint --edit "$1"
```

`package.json` additions:
```json
{
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md,yml,yaml}": [
      "prettier --write"
    ]
  }
}
```

### A11. Vitest config (`vitest.config.ts`)

```ts
import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      exclude: ["node_modules", "dist", "tests/e2e"],
    },
    include: ["tests/unit/**/*.test.ts"],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

### A12. Playwright config (`playwright.config.ts`)

```ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: "html",
  use: {
    baseURL: process.env.BASE_URL ?? "http://localhost:3000",
    trace: "on-first-retry",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
  ],
});
```

### A13. `package.json` scripts

Add these scripts — do not remove existing ones:

```json
{
  "scripts": {
    "dev": "bun run --watch src/index.ts",
    "build": "bun build src/index.ts --outdir dist --target bun",
    "start": "bun dist/index.js",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "release": "standard-version",
    "release:minor": "standard-version --release-as minor",
    "release:major": "standard-version --release-as major",
    "prepare": "husky"
  }
}
```

### A14. Recommended directory layout

```
project-root/
├── src/
│   ├── index.ts              # Entry point
│   ├── env.ts                # t3-env schema (import everywhere)
│   ├── lib/
│   │   ├── logger.ts         # Pino singleton
│   │   └── http.ts           # got instance + error wrapper
│   ├── schemas/              # Zod schemas
│   └── ...
├── tests/
│   ├── unit/                 # Vitest tests
│   └── e2e/                  # Playwright tests
├── .editorconfig
├── .eslintignore
├── .prettierrc
├── .prettierignore
├── commitlint.config.ts
├── playwright.config.ts
├── tsconfig.json
├── vitest.config.ts
└── .versionrc.json
```

---

## Section B — Adopt into Existing Project

When a project already exists, audit first — do not blindly overwrite.

1. **Run the audit script** → see `scripts/audit.sh`
2. For each ✗ item in the audit, apply only the missing piece from Section A.
3. Never remove deps the project already uses — add alongside.
4. If tsconfig exists but lacks `paths`, **merge** the `paths` key in; do not overwrite the whole file.
5. If ESLint config already exists (`.eslintrc.*`, `eslint.config.*`), **extend** it rather than replace.
6. If Husky is already initialised (`husky init` already ran), skip init and only add/update the hook files.

---

## Section C — Code Writing Conventions

> Read this section every time you write TypeScript code in this stack.
> See `references/writing-conventions.md` for detailed examples.

### C1. Logger — Pino

```ts
// src/lib/logger.ts  ← one singleton, imported everywhere
import pino from "pino";

const isDev = process.env.NODE_ENV !== "production";

export const logger = pino(
  isDev
    ? {
        transport: {
          target: "pino-pretty",
          options: { colorize: true, translateTime: "SYS:standard" },
        },
        level: "debug",
      }
    : { level: "info" },
);
```

**Rules:**
- Import `logger` from `@/lib/logger` — never instantiate pino again elsewhere.
- Use structured fields, not string interpolation: `logger.info({ userId }, "User logged in")` not `logger.info("User " + userId + " logged in")`.
- Choose the right level: `trace/debug` (dev detail), `info` (normal ops), `warn` (recoverable issues), `error` (failures), `fatal` (process must exit).
- Never log passwords, tokens, PII.

### C2. Environment Variables — t3-env

```ts
// src/env.ts
import { createEnv } from "@t3-oss/env-core";
import { z } from "zod";

export const env = createEnv({
  server: {
    NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
    PORT: z.coerce.number().min(1).max(65535).default(3000),
    DATABASE_URL: z.string().url(),
  },
  runtimeEnv: process.env,
});
```

**Rules:**
- All env access goes through `env` — never `process.env.ANYTHING` directly.
- Put `env.ts` at root of `src/`; import from `@/env`.
- Coerce numeric/boolean env vars with `z.coerce`.

### C3. HTTP Client — got + http-errors

```ts
// src/lib/http.ts
import got from "got";
import createHttpError from "http-errors";
import { logger } from "@/lib/logger";

export const http = got.extend({
  retry: { limit: 2 },
  timeout: { request: 10_000 },
  hooks: {
    afterResponse: [
      (response) => {
        logger.debug({ url: response.url, status: response.statusCode }, "HTTP response");
        return response;
      },
    ],
    beforeError: [
      (error) => {
        const { response } = error;
        if (response) {
          throw createHttpError(response.statusCode, response.body as string);
        }
        throw error;
      },
    ],
  },
});
```

**Rules:**
- Import `http` from `@/lib/http` — never use raw `got` elsewhere.
- Wrap all calls in try/catch; errors are `HttpError` instances from `http-errors`.
- Always check `isHttpError(err)` from `http-errors` before accessing `err.status`.

### C4. Type Validation — Zod

```ts
// src/schemas/user.ts
import { z } from "zod";

export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  role: z.enum(["admin", "user"]).default("user"),
  createdAt: z.coerce.date(),
});

export type User = z.infer<typeof UserSchema>;  // ← always derive type from schema
```

**Rules:**
- Use `z.infer<typeof Schema>` — never write a duplicate `type`/`interface`.
- Validate at every external boundary (API responses, env vars, user input, file reads).
- Use `.parse()` when you want it to throw on failure, `.safeParse()` when you want to handle the error yourself.
- Schemas live in `src/schemas/`; name files after the domain entity.

### C5. Path Aliases

```ts
// ✅ Correct
import { logger } from "@/lib/logger";
import { env } from "@/env";
import { UserSchema } from "@/schemas/user";

// ❌ Wrong — relative paths from deep files get messy
import { logger } from "../../../lib/logger";
```

**Rule:** Only `@/` is the allowed alias prefix. It maps to `src/`. Never add other aliases.

### C6. Testing

**Unit (Vitest):**
```ts
// tests/unit/schemas/user.test.ts
import { describe, it, expect } from "vitest";
import { UserSchema } from "@/schemas/user";

describe("UserSchema", () => {
  it("parses a valid user", () => {
    const result = UserSchema.parse({
      id: "123e4567-e89b-12d3-a456-426614174000",
      email: "test@example.com",
      createdAt: new Date().toISOString(),
    });
    expect(result.role).toBe("user");
  });

  it("rejects invalid email", () => {
    expect(() => UserSchema.parse({ email: "not-an-email" })).toThrow();
  });
});
```

**E2E (Playwright):**
```ts
// tests/e2e/home.spec.ts
import { test, expect } from "@playwright/test";

test("home page loads", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle(/My App/);
});
```

**Rules:**
- Unit tests mirror `src/` structure inside `tests/unit/`.
- E2E tests go in `tests/e2e/`.
- Run `bun test` for unit, `bun test:e2e` for E2E.
- Aim for ≥80% coverage on business logic (`src/schemas/`, `src/lib/`).

### C7. Commit Messages (Conventional Commits)

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

Examples:
```
feat(auth): add JWT refresh token flow
fix(http): handle 429 rate-limit with retry-after header
docs(readme): update env variable table
chore(deps): bump got to v14
```

**Rules:**
- Subject ≤72 chars, lowercase, no full stop.
- Commitlint enforces this — if your commit is rejected, fix the message format.
- Breaking changes: add `!` after type, e.g. `feat!: remove v1 API` and add `BREAKING CHANGE:` in footer.

### C8. Release & Changelog

```bash
# Patch release (bug fixes)
bun run release

# Minor release (new features)
bun run release:minor

# Major release (breaking changes)
bun run release:major
```

This bumps `package.json` version, generates/updates `CHANGELOG.md`, and creates a git tag. Then push:

```bash
git push --follow-tags origin main
```

---

## Quick Reference — Common Gotchas

| Situation | Wrong | Right |
|---|---|---|
| Access env var | `process.env.PORT` | `env.PORT` |
| HTTP call | `import got from "got"; got(url)` | `import { http } from "@/lib/http"; http(url)` |
| Log something | `console.log(msg)` | `logger.info({ ...ctx }, msg)` |
| Validate data | Manual `if` checks | `Schema.parse(data)` |
| Define type from schema | Write separate `type User = {...}` | `type User = z.infer<typeof UserSchema>` |
| Deep relative import | `../../../lib/logger` | `@/lib/logger` |
| Run tests | `npx vitest` | `bun test` |
| Commit message | `"fixed the bug"` | `"fix(scope): describe what and why"` |

---

## References

- `references/writing-conventions.md` — Extended code examples for each convention
- `references/troubleshooting.md` — Common errors and how to fix them
- `scripts/audit.sh` — Audits an existing project for missing tooling

Load a reference file when you need deep-dive examples or are debugging a specific tool.
