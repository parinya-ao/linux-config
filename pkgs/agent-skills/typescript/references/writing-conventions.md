# Writing Conventions — Extended Examples

Loaded by the skill when deeper examples are needed for a specific convention.

---

## Logger — pino

### Singleton pattern (full)

```ts
// src/lib/logger.ts
import pino, { type Logger } from "pino";
import { env } from "@/env";

const transport = env.NODE_ENV !== "production"
  ? {
      transport: {
        target: "pino-pretty",
        options: {
          colorize: true,
          translateTime: "SYS:standard",
          ignore: "pid,hostname",
          messageFormat: "{msg}",
        },
      },
    }
  : {};

export const logger: Logger = pino({
  level: env.NODE_ENV === "production" ? "info" : "debug",
  redact: {
    paths: ["password", "token", "authorization", "*.secret"],
    censor: "[REDACTED]",
  },
  ...transport,
});
```

### Child logger for request context

```ts
// Inside a request handler
const reqLogger = logger.child({ requestId: req.id, userId: req.user?.id });
reqLogger.info("Processing request");
reqLogger.error({ err }, "Request failed");
```

### Level guide

```ts
logger.trace({ data }, "Very verbose dev detail");   // dev only
logger.debug({ query }, "DB query");                 // dev debug
logger.info({ userId }, "User logged in");           // normal flow
logger.warn({ retries }, "Retry limit approaching"); // recoverable
logger.error({ err }, "Failed to send email");       // error, continue
logger.fatal({ err }, "Cannot connect to DB");       // must exit
```

---

## Zod — Validation Patterns

### API response validation

```ts
// src/schemas/github.ts
import { z } from "zod";

export const GithubUserSchema = z.object({
  login: z.string(),
  id: z.number().int().positive(),
  avatar_url: z.string().url(),
  public_repos: z.number().int().nonnegative(),
});

export type GithubUser = z.infer<typeof GithubUserSchema>;

// Usage — in a service
import { http } from "@/lib/http";
import { GithubUserSchema } from "@/schemas/github";
import { logger } from "@/lib/logger";

export async function getGithubUser(username: string): Promise<GithubUser> {
  const raw = await http(`https://api.github.com/users/${username}`).json();
  const result = GithubUserSchema.safeParse(raw);

  if (!result.success) {
    logger.error({ issues: result.error.issues, username }, "Unexpected GitHub API shape");
    throw new Error("Invalid GitHub API response");
  }

  return result.data;
}
```

### Request body validation (e.g. Hono/Elysia)

```ts
import { z } from "zod";

export const CreateUserBody = z.object({
  email: z.string().email().toLowerCase(),
  password: z.string().min(8).max(128),
  role: z.enum(["admin", "user"]).default("user"),
});

// In handler
const body = CreateUserBody.parse(await req.json());
// body is fully typed here
```

### Transform and refine

```ts
const DateRangeSchema = z
  .object({
    from: z.coerce.date(),
    to: z.coerce.date(),
  })
  .refine((d) => d.from <= d.to, {
    message: "'from' must be before or equal to 'to'",
    path: ["from"],
  });
```

### Union / discriminated union

```ts
const WebhookEventSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("push"), commits: z.array(z.string()) }),
  z.object({ type: z.literal("pull_request"), action: z.enum(["opened", "closed"]) }),
]);

type WebhookEvent = z.infer<typeof WebhookEventSchema>;
```

---

## got + http-errors — HTTP Patterns

### Typed JSON response

```ts
import { http } from "@/lib/http";
import { isHttpError } from "http-errors";
import { logger } from "@/lib/logger";
import { GithubUserSchema, type GithubUser } from "@/schemas/github";

export async function fetchUser(username: string): Promise<GithubUser> {
  try {
    const raw = await http(`https://api.github.com/users/${username}`).json();
    return GithubUserSchema.parse(raw);
  } catch (err) {
    if (isHttpError(err)) {
      // err.status, err.message are typed
      logger.warn({ status: err.status, username }, "GitHub user not found");
      throw err; // re-throw as HttpError for the caller to handle
    }
    throw err;
  }
}
```

### POST with JSON body

```ts
const result = await http
  .post("https://api.example.com/tasks", {
    json: { title: "My Task", done: false },
    headers: { Authorization: `Bearer ${env.API_TOKEN}` },
  })
  .json();
```

### HTTP error handler middleware pattern

```ts
// Error handler (framework-agnostic example)
import { isHttpError } from "http-errors";
import { logger } from "@/lib/logger";

export function handleError(err: unknown): { status: number; message: string } {
  if (isHttpError(err)) {
    logger.warn({ status: err.status }, err.message);
    return { status: err.status, message: err.message };
  }

  logger.error({ err }, "Unhandled error");
  return { status: 500, message: "Internal server error" };
}
```

---

## t3-env — Environment Patterns

### Full server env schema

```ts
// src/env.ts
import { createEnv } from "@t3-oss/env-core";
import { z } from "zod";

export const env = createEnv({
  server: {
    NODE_ENV: z
      .enum(["development", "test", "production"])
      .default("development"),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    HOST: z.string().default("0.0.0.0"),
    DATABASE_URL: z.string().url(),
    REDIS_URL: z.string().url().optional(),
    JWT_SECRET: z.string().min(32),
    API_TOKEN: z.string().min(1),
    LOG_LEVEL: z
      .enum(["trace", "debug", "info", "warn", "error", "fatal"])
      .default("info"),
  },
  runtimeEnv: process.env,
  emptyStringAsUndefined: true,
});
```

### `.env.example` to commit alongside

```dotenv
# Application
NODE_ENV=development
PORT=3000
HOST=0.0.0.0

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/mydb

# Cache (optional)
# REDIS_URL=redis://localhost:6379

# Auth
JWT_SECRET=change-me-to-at-least-32-chars-long
API_TOKEN=your-api-token-here

# Logging
LOG_LEVEL=debug
```

---

## Vitest — Testing Patterns

### Testing a service that uses got + zod

```ts
// tests/unit/services/github.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock the http module at the top level
vi.mock("@/lib/http", () => ({
  http: Object.assign(
    vi.fn().mockReturnValue({
      json: vi.fn(),
    }),
    { post: vi.fn(), get: vi.fn() },
  ),
}));

import { http } from "@/lib/http";
import { fetchUser } from "@/services/github";

describe("fetchUser", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns parsed user on success", async () => {
    const mockRaw = {
      login: "octocat",
      id: 1,
      avatar_url: "https://github.com/images/octocat.png",
      public_repos: 10,
    };
    // @ts-expect-error – mocked
    http.mockReturnValue({ json: vi.fn().mockResolvedValue(mockRaw) });

    const user = await fetchUser("octocat");
    expect(user.login).toBe("octocat");
    expect(user.id).toBe(1);
  });

  it("throws HttpError on 404", async () => {
    const { createHttpError } = await import("http-errors");
    // @ts-expect-error – mocked
    http.mockReturnValue({
      json: vi.fn().mockRejectedValue(createHttpError(404, "Not Found")),
    });

    await expect(fetchUser("nobody")).rejects.toMatchObject({ status: 404 });
  });
});
```

### Testing Zod schemas

```ts
import { describe, it, expect } from "vitest";
import { CreateUserBody } from "@/schemas/user";

describe("CreateUserBody", () => {
  it("lowercases email", () => {
    const result = CreateUserBody.parse({ email: "TEST@EXAMPLE.COM", password: "secure123" });
    expect(result.email).toBe("test@example.com");
  });

  it("defaults role to user", () => {
    const result = CreateUserBody.parse({ email: "a@b.com", password: "password1" });
    expect(result.role).toBe("user");
  });

  it("rejects short password", () => {
    expect(() => CreateUserBody.parse({ email: "a@b.com", password: "short" })).toThrow();
  });
});
```

---

## Path Aliases — Why `@/` Only

The single `@/` alias keeps imports predictable:

```ts
// Any file anywhere in src/ uses the same import
import { logger } from "@/lib/logger";      // not ../../../lib/logger
import { env } from "@/env";               // not ../../env
import { UserSchema } from "@/schemas/user"; // always clear where it lives
```

The alias is registered in three places — they must all match:

1. **tsconfig.json** → `"paths": { "@/*": ["./src/*"] }`
2. **vitest.config.ts** → `resolve: { alias: { "@": path.resolve(__dirname, "./src") } }`
3. **Bun** → Bun reads tsconfig paths natively; no extra config needed.
