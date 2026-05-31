# Troubleshooting — Common Errors & Fixes

---

## Bun

### `bun: command not found` after install
```bash
source ~/.bashrc   # or ~/.zshrc / ~/.profile
# then verify
bun --version
```

### TypeScript path alias `@/` not resolving in Bun
Bun reads `tsconfig.json` paths automatically. Check:
1. `tsconfig.json` has `"paths": { "@/*": ["./src/*"] }` under `compilerOptions`
2. You're running via `bun run src/index.ts` (not `node`)
3. `baseUrl` is set to `"."` in tsconfig

---

## ESLint

### `Parsing error: "parserOptions.project" has been set`
ESLint can't find tsconfig for a file. Solutions:
```js
// In eslint.config.mjs, ensure the files glob matches:
files: ["**/*.ts"],
// AND tsconfig includes the file in "include":
// "include": ["src/**/*", "tests/**/*"]
```

### `eslint.config.mjs` not picked up
You may have a legacy `.eslintrc.*` file blocking it. Remove the old one:
```bash
rm -f .eslintrc .eslintrc.js .eslintrc.json .eslintrc.yaml .eslintrc.yml
```

---

## Husky

### Hooks not running after `git commit`
```bash
# Ensure hooks are executable
chmod +x .husky/pre-commit .husky/commit-msg
# Ensure husky is installed
bun run prepare
```

### `commit-msg: bun: not found` in some shells
Add to `.husky/commit-msg`:
```sh
export PATH="$HOME/.bun/bin:$PATH"
bun run commitlint --edit "$1"
```

---

## Commitlint

### Commit rejected with "subject-case"
```
✖   subject must not be sentence-case, start-case, pascal-case, upper-case [subject-case]
```
Fix: make the subject all lowercase.
```
# Wrong
feat(auth): Add JWT Refresh Token

# Right
feat(auth): add jwt refresh token
```

### Commit rejected with "type-enum"
You used a type not in the allowed list. Check `commitlint.config.ts` for the valid types.

---

## Zod

### `.parse()` throws unexpectedly
Use `.safeParse()` to inspect what failed:
```ts
const result = MySchema.safeParse(data);
if (!result.success) {
  console.error(result.error.format());  // shows exactly which fields
}
```

### `z.coerce.date()` returning Invalid Date
The input might be `null` or `undefined`. Add `.nullable()` or `.optional()`:
```ts
z.coerce.date().nullable()
```

---

## got + http-errors

### `RequestError: connect ECONNREFUSED`
The server isn't running or the URL is wrong. Check:
1. The base URL in `http.ts` / env var
2. The server process is up (`bun dev`)

### `isHttpError(err)` returns false
You're catching a `got` `RequestError`, not an `HttpError`. The `beforeError` hook in `src/lib/http.ts` converts HTTP errors — but only if the response has a status code. Network errors (ECONNREFUSED, timeout) stay as `RequestError`. Check separately:
```ts
import got from "got";
import { isHttpError } from "http-errors";

if (isHttpError(err)) {
  // HTTP 4xx/5xx
} else if (err instanceof got.RequestError) {
  // Network / timeout
} else {
  // Unknown
}
```

---

## t3-env

### `Invalid environment variables`
t3-env logs the exact failing variable. Common causes:
- Variable missing from `.env` file
- Wrong type (e.g. `PORT=abc` when schema expects a number — use `z.coerce.number()`)
- Empty string when variable is required — add `emptyStringAsUndefined: true` to `createEnv`

### `Cannot access env before initialization`
You imported something that imports `env.ts` at module top-level during a Vitest test. Fix: mock `@/env` in your test:
```ts
vi.mock("@/env", () => ({
  env: {
    NODE_ENV: "test",
    PORT: 3000,
    DATABASE_URL: "postgresql://localhost/test",
    JWT_SECRET: "test-secret-at-least-32-chars-long",
    API_TOKEN: "test-token",
  },
}));
```

---

## Vitest

### `Cannot find module '@/...'` in tests
vitest.config.ts must have the alias:
```ts
resolve: {
  alias: { "@": path.resolve(__dirname, "./src") },
},
```

### Coverage not excluding e2e tests
Add to vitest.config.ts:
```ts
coverage: {
  exclude: ["node_modules", "dist", "tests/e2e/**", "playwright.config.ts"],
}
```

---

## standard-version

### `CHANGELOG.md` shows commits that should be hidden
Ensure your `.versionrc.json` has `"hidden": true` for types you want to exclude (like `chore`).

### `standard-version` bumps patch when you expected minor
Only `feat` commits trigger a minor bump. If all your commits since the last tag are `fix`/`chore`, it bumps patch. Use `--release-as minor` to override.

### Git tag already exists
```bash
git tag -d v1.0.0         # delete local tag
git push origin :v1.0.0   # delete remote tag
bun run release            # then release again
```
