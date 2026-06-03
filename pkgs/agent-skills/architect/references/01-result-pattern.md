# Reference 01 — Result Pattern & Railway-Oriented Programming

## Why Not Try-Catch?

`try-catch` for business errors has a critical flaw: it's **invisible in the type system**.
When a function can fail, nothing in its signature tells the caller what can go wrong.
The caller might forget to handle it, and the program crashes at runtime.

```typescript
// ❌ What errors can this throw? Nobody knows without reading the entire implementation.
async function chargeCustomer(customerId: string, amount: number): Promise<Receipt>
```

The Result Pattern fixes this. Every possible outcome is declared in the return type.
The caller is forced by TypeScript to handle both success and failure paths.

```typescript
// ✅ Perfectly clear: it either succeeds with a Receipt, or fails with a BillingError
async function chargeCustomer(
  customerId: string,
  amount: number,
): Promise<Result<Receipt, BillingError>>
```

---

## The Core Type — Copy This to `src/shared/result.ts`

```typescript
// src/shared/result.ts

export type Ok<T>  = { readonly success: true;  readonly value: T }
export type Err<E> = { readonly success: false; readonly error: E }
export type Result<T, E> = Ok<T> | Err<E>

/** Wrap a successful value */
export const ok  = <T>(value: T): Ok<T>  => ({ success: true,  value })

/** Wrap a business failure */
export const err = <E>(error: E): Err<E> => ({ success: false, error })

/** Type guard: narrows Result<T,E> to Ok<T> */
export const isOk  = <T, E>(r: Result<T, E>): r is Ok<T>  => r.success === true

/** Type guard: narrows Result<T,E> to Err<E> */
export const isErr = <T, E>(r: Result<T, E>): r is Err<E> => r.success === false

/**
 * Synchronous pipe — chain transformations down the railway.
 * If result is Err, skip fn entirely and pass the error through.
 * If result is Ok, apply fn and return its Result.
 */
export function pipe<T, E, U>(
  result: Result<T, E>,
  fn: (value: T) => Result<U, E>,
): Result<U, E> {
  return result.success ? fn(result.value) : result
}

/**
 * Async pipe — same as pipe but fn returns a Promise<Result>.
 * Use for database lookups, HTTP calls, etc.
 */
export async function pipeAsync<T, E, U>(
  result: Result<T, E>,
  fn: (value: T) => Promise<Result<U, E>>,
): Promise<Result<U, E>> {
  return result.success ? fn(result.value) : result
}

/**
 * Combine multiple Results — fails fast on the first Err.
 * Use when you need several independent checks to all pass.
 */
export function combineResults<T, E>(results: Result<T, E>[]): Result<T[], E> {
  const values: T[] = []
  for (const result of results) {
    if (!result.success) return result
    values.push(result.value)
  }
  return ok(values)
}
```

---

## Designing Error Domains

Each business domain should have its own **error union type** — a discriminated union where
every member has a `kind` field. This makes exhaustive error handling trivial with a `switch`.

```typescript
// src/billing/billing.errors.ts

export type BillingError =
  | { kind: 'CUSTOMER_NOT_FOUND';       customerId: string }
  | { kind: 'INSUFFICIENT_FUNDS';       availableBalance: number; requiredAmount: number }
  | { kind: 'PAYMENT_METHOD_EXPIRED';   expiredAt: Date }
  | { kind: 'PAYMENT_PROVIDER_UNAVAILABLE'; retryAfterSeconds: number }
  | { kind: 'AMOUNT_BELOW_MINIMUM';     minimumAmount: number; providedAmount: number }
```

**Rules for error domains:**
1. `kind` is always a SCREAMING_SNAKE_CASE string — specific enough to act on
2. Include all the data needed to handle the error (amounts, IDs, dates)
3. Never use a generic `{ kind: 'ERROR'; message: string }` — that's meaningless
4. Group errors by domain, not by severity

---

## Full Business Example — Billing Domain

This shows the complete railway from HTTP input → domain logic → infrastructure → HTTP response.

```typescript
// src/billing/billing.errors.ts
export type BillingError =
  | { kind: 'CUSTOMER_NOT_FOUND';      customerId: string }
  | { kind: 'INSUFFICIENT_FUNDS';      available: number; required: number }
  | { kind: 'PAYMENT_METHOD_EXPIRED';  expiredAt: Date }
  | { kind: 'CHARGE_AMOUNT_INVALID';   reason: 'TOO_LOW' | 'TOO_HIGH'; amount: number }


// src/billing/billing.domain.ts  ← Pure domain logic, zero imports from infrastructure
import { type Result, ok, err } from '../shared/result.ts'
import type { BillingError } from './billing.errors.ts'

const MINIMUM_CHARGE_AMOUNT_IN_CENTS = 50
const MAXIMUM_CHARGE_AMOUNT_IN_CENTS = 99_999_99

export type Customer = {
  id: string
  balanceInCents: number
  paymentMethodExpiresAt: Date
}

export type ChargeReceipt = {
  receiptId: string
  customerId: string
  amountChargedInCents: number
  chargedAt: Date
}

/** Step 1: Validate the charge amount is within acceptable bounds */
export function validateChargeAmountIsWithinAcceptableBounds(
  amountInCents: number,
): Result<number, BillingError> {
  if (amountInCents < MINIMUM_CHARGE_AMOUNT_IN_CENTS) {
    return err({ kind: 'CHARGE_AMOUNT_INVALID', reason: 'TOO_LOW', amount: amountInCents })
  }
  if (amountInCents > MAXIMUM_CHARGE_AMOUNT_IN_CENTS) {
    return err({ kind: 'CHARGE_AMOUNT_INVALID', reason: 'TOO_HIGH', amount: amountInCents })
  }
  return ok(amountInCents)
}

/** Step 2: Verify the customer's payment method has not expired */
export function verifyCustomerPaymentMethodHasNotExpired(
  customer: Customer,
): Result<Customer, BillingError> {
  const now = new Date()
  if (customer.paymentMethodExpiresAt < now) {
    return err({ kind: 'PAYMENT_METHOD_EXPIRED', expiredAt: customer.paymentMethodExpiresAt })
  }
  return ok(customer)
}

/** Step 3: Check the customer has sufficient funds for the charge */
export function checkCustomerHasSufficientFundsForCharge(
  customer: Customer,
  amountInCents: number,
): Result<{ customer: Customer; amountInCents: number }, BillingError> {
  if (customer.balanceInCents < amountInCents) {
    return err({
      kind: 'INSUFFICIENT_FUNDS',
      available: customer.balanceInCents,
      required: amountInCents,
    })
  }
  return ok({ customer, amountInCents })
}

/** The assembled domain rule: all checks must pass before a charge is approved */
export function assembleApprovedChargeForCustomer(
  customer: Customer,
  amountInCents: number,
): Result<{ customer: Customer; amountInCents: number }, BillingError> {
  const validAmount = validateChargeAmountIsWithinAcceptableBounds(amountInCents)
  if (!validAmount.success) return validAmount

  const validPaymentMethod = verifyCustomerPaymentMethodHasNotExpired(customer)
  if (!validPaymentMethod.success) return validPaymentMethod

  return checkCustomerHasSufficientFundsForCharge(customer, amountInCents)
}


// src/billing/billing.repo.ts  ← Port (interface) — domain defines what it needs
import type { Result } from '../shared/result.ts'
import type { Customer, ChargeReceipt } from './billing.domain.ts'
import type { BillingError } from './billing.errors.ts'

export type FindCustomerById   = (id: string) => Promise<Result<Customer, BillingError>>
export type SaveChargeReceipt  = (receipt: ChargeReceipt) => Promise<Result<ChargeReceipt, BillingError>>


// src/billing/billing.service.ts  ← Orchestrates domain + infrastructure ports
import { pipe, pipeAsync } from '../shared/result.ts'
import { assembleApprovedChargeForCustomer } from './billing.domain.ts'
import type { FindCustomerById, SaveChargeReceipt } from './billing.repo.ts'
import type { Result } from '../shared/result.ts'
import type { BillingError } from './billing.errors.ts'
import type { ChargeReceipt } from './billing.domain.ts'

export async function chargeCustomerForOrderTotal(
  customerId: string,
  orderTotalInCents: number,
  findCustomerById: FindCustomerById,
  saveChargeReceipt: SaveChargeReceipt,
): Promise<Result<ChargeReceipt, BillingError>> {

  // Step 1: Find the customer (may fail with CUSTOMER_NOT_FOUND)
  const customerResult = await findCustomerById(customerId)
  if (!customerResult.success) return customerResult

  // Step 2: Run all domain checks (amount, payment method, funds)
  const approvedCharge = assembleApprovedChargeForCustomer(
    customerResult.value,
    orderTotalInCents,
  )
  if (!approvedCharge.success) return approvedCharge

  // Step 3: Persist the charge receipt
  const receipt: ChargeReceipt = {
    receiptId: crypto.randomUUID(),
    customerId,
    amountChargedInCents: orderTotalInCents,
    chargedAt: new Date(),
  }
  return saveChargeReceipt(receipt)
}
```

---

## Async Results Pattern

When domain logic calls infrastructure, the function returns `Promise<Result<T,E>>`.
Use `await` before checking `.success`.

```typescript
// Correct pattern for async results
const customerResult = await findCustomerById(customerId)
if (!customerResult.success) return customerResult // pass the error through
const customer = customerResult.value              // TypeScript knows this is Customer

// Using pipeAsync for cleaner chaining
const finalResult = await pipeAsync(
  await findCustomerById(customerId),
  (customer) => chargeCustomerForOrderTotal(customer, orderTotal, saveReceipt),
)
```

---

## Converting Results at the HTTP Boundary

The HTTP layer is the only place that converts `Result<T,E>` into HTTP responses.
Domain logic never knows about HTTP status codes.

```typescript
// src/billing/billing.http.ts
import type { Context } from 'hono'
import { chargeCustomerForOrderTotal } from './billing.service.ts'
import type { BillingError } from './billing.errors.ts'

function convertBillingErrorToHttpResponse(error: BillingError, c: Context) {
  switch (error.kind) {
    case 'CUSTOMER_NOT_FOUND':
      return c.json({ error: 'Customer not found', customerId: error.customerId }, 404)

    case 'INSUFFICIENT_FUNDS':
      return c.json({
        error: 'Insufficient funds',
        available: error.available,
        required: error.required,
      }, 422)

    case 'PAYMENT_METHOD_EXPIRED':
      return c.json({ error: 'Payment method expired', expiredAt: error.expiredAt }, 422)

    case 'CHARGE_AMOUNT_INVALID':
      return c.json({ error: 'Invalid charge amount', reason: error.reason }, 400)

    case 'PAYMENT_PROVIDER_UNAVAILABLE':
      return c.json({ error: 'Service temporarily unavailable' }, 503)

    default: {
      // TypeScript exhaustiveness check — compile error if a case is missing
      const _exhaustive: never = error
      return c.json({ error: 'Unexpected error' }, 500)
    }
  }
}

export async function handleChargeCustomerRequest(c: Context) {
  const { customerId, amountInCents } = await c.req.json()

  // Pass infrastructure dependencies as functions (Dependency Injection)
  const result = await chargeCustomerForOrderTotal(
    customerId,
    amountInCents,
    findCustomerByIdFromPostgres,  // injected adapter
    saveChargeReceiptToPostgres,   // injected adapter
  )

  if (!result.success) {
    return convertBillingErrorToHttpResponse(result.error, c)
  }

  return c.json({ receipt: result.value }, 201)
}
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `throw new Error('Insufficient funds')` | Invisible to type system, crashes at runtime | Return `err({ kind: 'INSUFFICIENT_FUNDS', ... })` |
| `catch (e: any) { ... }` | Loses type information | Use Result — never catch expected errors |
| `Result<T, string>` | String errors are useless | Use a discriminated union error type |
| `Result<T, Error>` | Extends Error gives no domain info | Use a domain-specific error type |
| Nesting Results: `Result<Result<T,E>,E>` | Confusing | Use `pipe()` to flatten |
| Ignoring the error: `if (result.success) { use(result.value) }` | Error silently dropped | Always `return result` when not handling |
