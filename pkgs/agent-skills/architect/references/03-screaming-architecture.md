# Reference 03 — Screaming Architecture & Domain Organization

## The Mental Model

Imagine a new developer joins the team today. They clone the repo, open `src/`, and look at
the folder names. In 10 seconds, they should understand **what the application does**.

```
src/
├── order/       ← "This app processes orders"
├── billing/     ← "It handles billing"
├── inventory/   ← "It tracks inventory"
├── customer/    ← "It manages customers"
└── shared/      ← "These utilities are used everywhere"
```

Contrast with the anti-pattern:
```
src/
├── controllers/   ← "It has controllers" — so does every app, useless
├── services/      ← "It has services" — obviously
├── models/        ← "It has models" — every app has models
└── repositories/  ← Technical term that hides the business
```

---

## The Hexagonal Architecture Mapping

Each domain folder maps to a simplified Hexagonal (Ports & Adapters) structure:

```
domain-name/
├── domain-name.domain.ts       ← HEXAGON CORE: Pure business rules
│                                  No imports from infrastructure.
│                                  Only plain TypeScript types and logic.
│
├── domain-name.errors.ts       ← Error union types (used by both core and adapters)
│
├── domain-name.repo.ts         ← PORT: Interface the domain needs from the outside
│                                  Defined in the domain language — the domain "asks for"
│                                  a function, not a database connection.
│
├── domain-name.service.ts      ← ORCHESTRATOR: Wires domain + ports together
│                                  Uses async, calls domain logic, calls port functions.
│                                  Still no infrastructure imports.
│
├── domain-name.postgres-repo.ts ← ADAPTER (DB): Postgres implementation of the port
│                                   Imports pg/drizzle/prisma here — not in domain.
│
├── domain-name.http.ts          ← ADAPTER (HTTP): Routes and request handlers
│                                   Imports Hono/Elysia here. Converts HTTP ↔ domain.
│                                   Converts Result<T,E> → HTTP status codes.
│
└── domain-name.test.ts          ← LIVING DOCUMENTATION: Unit tests for domain logic
                                    Tests domain.ts and service.ts with fake adapters.
                                    Zero real DB or HTTP in these tests.
```

**The Golden Rule:** Imports flow **inward only**.
```
http.ts → service.ts → domain.ts ← (no imports going out from domain.ts)
postgres-repo.ts → (implements port from domain.ts)
```

---

## Folder Structure Templates

### Small Feature (1 simple domain concept)

Use this for features that touch one concept: a coupon, a notification, a webhook.

```
src/
├── coupon/
│   ├── coupon.domain.ts         ← Business rules (validate, apply, expire)
│   ├── coupon.errors.ts         ← CouponError union
│   ├── coupon.repo.ts           ← Port: FindCouponByCode, SaveCoupon
│   ├── coupon.postgres-repo.ts  ← Postgres adapter
│   ├── coupon.http.ts           ← POST /coupons/validate, POST /coupons/apply
│   └── coupon.test.ts           ← Living docs for coupon rules
└── shared/
    └── result.ts                ← Result<T,E> + pipe utilities
```

### Medium Feature (1 rich domain with subdomains)

Use this when one concept has multiple distinct responsibilities.

```
src/
├── order/
│   ├── checkout/
│   │   ├── checkout.domain.ts       ← Rules for checkout eligibility
│   │   ├── checkout.errors.ts
│   │   ├── checkout.service.ts
│   │   └── checkout.test.ts
│   ├── fulfillment/
│   │   ├── fulfillment.domain.ts    ← Rules for order fulfillment lifecycle
│   │   ├── fulfillment.errors.ts
│   │   ├── fulfillment.service.ts
│   │   └── fulfillment.test.ts
│   ├── order.repo.ts                ← Shared port for the order domain
│   ├── order.postgres-repo.ts       ← Shared DB adapter
│   ├── order.http.ts                ← All order routes in one place
│   └── order.types.ts               ← Shared types (Order, OrderLineItem, etc.)
└── shared/
    └── result.ts
```

### Large Application (Multiple rich domains)

```
src/
├── customer/
│   ├── registration/
│   │   ├── registration.domain.ts
│   │   ├── registration.errors.ts
│   │   ├── registration.service.ts
│   │   └── registration.test.ts
│   ├── authentication/
│   │   ├── authentication.domain.ts
│   │   ├── authentication.errors.ts
│   │   ├── authentication.service.ts
│   │   └── authentication.test.ts
│   ├── customer.repo.ts
│   ├── customer.postgres-repo.ts
│   └── customer.http.ts
│
├── order/
│   ├── checkout/
│   ├── fulfillment/
│   ├── order.repo.ts
│   ├── order.postgres-repo.ts
│   └── order.http.ts
│
├── billing/
│   ├── billing.domain.ts
│   ├── billing.errors.ts
│   ├── billing.repo.ts
│   ├── billing.stripe-adapter.ts   ← External payment provider adapter
│   ├── billing.postgres-repo.ts
│   ├── billing.service.ts
│   ├── billing.http.ts
│   └── billing.test.ts
│
├── inventory/
│   ├── inventory.domain.ts
│   ├── inventory.errors.ts
│   ├── inventory.repo.ts
│   ├── inventory.postgres-repo.ts
│   ├── inventory.service.ts
│   ├── inventory.http.ts
│   └── inventory.test.ts
│
├── shared/
│   ├── result.ts                   ← Result<T,E> type and utilities
│   ├── pagination.ts               ← Shared pagination types
│   └── money.ts                    ← Money/currency utilities (if needed)
│
└── app.ts                          ← Hono/Elysia app setup + route mounting
```

---

## What Goes Where — Decision Table

| Code | Where it lives | Why |
|---|---|---|
| Business rules (if customer is VIP...) | `*.domain.ts` | Pure logic, no side effects |
| Error types (discriminated union) | `*.errors.ts` | Shared by domain + adapters |
| Port definitions (interfaces/function types) | `*.repo.ts` | Domain defines what it needs |
| SQL queries / ORM calls | `*.postgres-repo.ts` | Infrastructure adapter |
| HTTP route definitions | `*.http.ts` | HTTP adapter |
| External API calls (Stripe, SendGrid) | `*.<service>-adapter.ts` | External adapter |
| Orchestration (call domain, then call repo) | `*.service.ts` | Use-case layer |
| Tests for domain rules | `*.test.ts` | Same folder as the domain |
| Shared TypeScript types | `*.types.ts` or `shared/` | Depends on scope |
| `Result<T,E>` utilities | `shared/result.ts` | Used by all domains |
| Logging | Infrastructure adapters only | Never in domain logic |
| Zod schemas for parsing | HTTP adapter or repo adapter | At the boundary |
| Environment variables | `shared/env.ts` with t3-env | Parsed once at startup |
| Database connection pool | `shared/db.ts` | Single point of truth |

---

## Port Design — The Domain Asks, Infrastructure Answers

Ports are **function types** defined by the domain to describe what it needs.
The domain doesn't care if the answer comes from Postgres, Redis, or a test double.

```typescript
// src/order/order.repo.ts  ← Port: the domain defines what it needs

import type { Result } from '../shared/result.ts'
import type { Order, OrderLineItem } from './order.types.ts'
import type { OrderError } from './order.errors.ts'

// The domain needs these capabilities from the outside world
export type FindOrderById           = (id: string) => Promise<Result<Order, OrderError>>
export type FindActiveOrdersForCustomer = (customerId: string) => Promise<Result<Order[], OrderError>>
export type SaveOrder               = (order: Order) => Promise<Result<Order, OrderError>>
export type UpdateOrderFulfillmentStatus = (
  orderId: string,
  status: Order['fulfillmentStatus'],
) => Promise<Result<Order, OrderError>>
```

```typescript
// src/order/order.postgres-repo.ts  ← Adapter: Postgres implementation

import { db } from '../shared/db.ts'
import { ok, err } from '../shared/result.ts'
import type { FindOrderById, SaveOrder } from './order.repo.ts'

export const findOrderByIdFromPostgres: FindOrderById = async (id) => {
  const row = await db.query('SELECT * FROM orders WHERE id = $1', [id])
  if (!row) return err({ kind: 'ORDER_NOT_FOUND', orderId: id })
  return ok(mapRowToOrder(row))
}

export const saveOrderToPostgres: SaveOrder = async (order) => {
  // ... SQL INSERT/UPDATE
  return ok(order)
}
```

---

## Anti-Patterns

### ❌ Anti-Pattern 1: Technical Layer Folders
```
src/controllers/OrderController.ts   ← Doesn't tell me what orders DO
src/services/OrderService.ts         ← Doesn't tell me which domain
src/models/Order.ts                  ← Disconnected from its behavior
src/repositories/OrderRepository.ts  ← Disconnected from domain
```

### ❌ Anti-Pattern 2: God Files
```
src/order/order.ts   ← 2000 lines containing EVERYTHING about orders
```
Split by layer (domain, service, http, repo) even if each file is small.

### ❌ Anti-Pattern 3: Infrastructure in Domain Logic
```typescript
// src/billing/billing.domain.ts
import { db } from '../shared/db.ts'      // ← WRONG: domain imports DB
import Stripe from 'stripe'               // ← WRONG: domain imports Stripe

export async function chargeCustomer(customerId: string, amount: number) {
  const customer = await db.customers.find(customerId)  // ← WRONG
  return stripe.charges.create({ amount })              // ← WRONG
}
```

### ❌ Anti-Pattern 4: Barrel Exports Hiding Everything
```typescript
// src/index.ts — exports everything from everywhere
export * from './order/order.domain.ts'
export * from './billing/billing.domain.ts'
// 50 more lines...
```
Only use barrel exports at the application boundary when needed for an external API.

### ❌ Anti-Pattern 5: Shared Utilities Folder Becoming a Dumping Ground
```
src/utils/
├── string-helpers.ts
├── date-helpers.ts
├── validation.ts       ← Which domain? Which rules?
├── constants.ts        ← Constants for what?
├── types.ts            ← Types for what?
└── ...                 ← 40 more files
```
If a utility belongs to a specific domain, put it in that domain's folder.
If it's truly shared, name it specifically: `shared/money-formatting.ts`.
