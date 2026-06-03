# Reference 04 — Living Documentation & TDD Mindset

## Why Tests Are Documentation

Code comments lie. They get out of date. Developers forget to update them.
But **tests cannot lie** — they either pass or they don't.

A test file for a domain is a complete, always-accurate specification of every business rule.
When a new developer joins, they read the test file first — not the docs, not the Confluence page,
not the comments. The test names are the spec.

The goal: a product manager should be able to read the test names and confirm that the code
implements the correct business rules — even without understanding TypeScript.

---

## The Mandatory Naming Format

```
should_<expected_behavior>_when_<business_condition>
```

Every test name must be a complete English sentence that:
1. Describes **exactly one** business behavior (the `should_` part)
2. States the specific condition that triggers it (the `when_` part)

```typescript
// ✅ Perfect test names — a complete business specification
describe('checkout eligibility rules', () => {
  it('should_allow_checkout_when_cart_has_at_least_one_item')
  it('should_reject_checkout_when_cart_is_empty')
  it('should_reject_checkout_when_customer_email_is_not_verified')
  it('should_reject_checkout_when_customer_account_is_suspended')
  it('should_allow_checkout_for_guest_customers_without_email_verification')
})

// ❌ Terrible test names — tell me nothing about the business
describe('checkout', () => {
  it('test 1')
  it('works correctly')
  it('validates input')
  it('returns error')
  it('handles edge case')
})
```

---

## Test File Structure

Organize tests by **business scenario**, not by function name.

```typescript
// src/billing/billing.test.ts
import { describe, it, expect } from 'vitest'
import {
  validateChargeAmountIsWithinAcceptableBounds,
  verifyCustomerPaymentMethodHasNotExpired,
  checkCustomerHasSufficientFundsForCharge,
  assembleApprovedChargeForCustomer,
} from './billing.domain.ts'
import { ok, err } from '../shared/result.ts'
import type { Customer } from './billing.domain.ts'

// ── Test Fixtures ──────────────────────────────────────────────────────────────
// Fixtures are named builders — they make tests self-describing

const aCustomerWithSufficientFunds = (overrides?: Partial<Customer>): Customer => ({
  id: 'customer-123',
  balanceInCents: 10_000,
  paymentMethodExpiresAt: new Date('2099-01-01'),
  ...overrides,
})

const aCustomerWithExpiredPaymentMethod = (): Customer =>
  aCustomerWithSufficientFunds({ paymentMethodExpiresAt: new Date('2020-01-01') })

const aCustomerWithInsufficientFunds = (balanceInCents: number): Customer =>
  aCustomerWithSufficientFunds({ balanceInCents })

// ── Charge Amount Validation ──────────────────────────────────────────────────
describe('charge amount validation', () => {
  it('should_accept_a_charge_amount_that_is_above_the_minimum_threshold', () => {
    const result = validateChargeAmountIsWithinAcceptableBounds(100)
    expect(result).toEqual(ok(100))
  })

  it('should_reject_a_charge_when_amount_is_below_the_50_cent_minimum', () => {
    const result = validateChargeAmountIsWithinAcceptableBounds(49)
    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error.kind).toBe('CHARGE_AMOUNT_INVALID')
      expect(result.error.reason).toBe('TOO_LOW')
    }
  })

  it('should_reject_a_charge_when_amount_exceeds_the_maximum_allowed_limit', () => {
    const result = validateChargeAmountIsWithinAcceptableBounds(9_999_999)
    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error.kind).toBe('CHARGE_AMOUNT_INVALID')
      expect(result.error.reason).toBe('TOO_HIGH')
    }
  })

  it('should_accept_a_charge_at_exactly_the_minimum_boundary', () => {
    const result = validateChargeAmountIsWithinAcceptableBounds(50)
    expect(result).toEqual(ok(50))
  })
})

// ── Payment Method Verification ───────────────────────────────────────────────
describe('payment method expiry verification', () => {
  it('should_approve_charge_when_payment_method_expires_in_the_future', () => {
    const customer = aCustomerWithSufficientFunds()
    const result = verifyCustomerPaymentMethodHasNotExpired(customer)
    expect(result).toEqual(ok(customer))
  })

  it('should_reject_charge_when_payment_method_has_already_expired', () => {
    const customer = aCustomerWithExpiredPaymentMethod()
    const result = verifyCustomerPaymentMethodHasNotExpired(customer)
    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error.kind).toBe('PAYMENT_METHOD_EXPIRED')
    }
  })
})

// ── Sufficient Funds Verification ─────────────────────────────────────────────
describe('sufficient funds verification', () => {
  it('should_approve_charge_when_customer_balance_exactly_equals_order_total', () => {
    const customer = aCustomerWithSufficientFunds({ balanceInCents: 5_000 })
    const result = checkCustomerHasSufficientFundsForCharge(customer, 5_000)
    expect(result.success).toBe(true)
  })

  it('should_approve_charge_when_customer_balance_exceeds_order_total', () => {
    const customer = aCustomerWithSufficientFunds({ balanceInCents: 10_000 })
    const result = checkCustomerHasSufficientFundsForCharge(customer, 5_000)
    expect(result.success).toBe(true)
  })

  it('should_fail_with_insufficient_funds_error_when_balance_is_one_cent_below_total', () => {
    const customer = aCustomerWithInsufficientFunds(4_999)
    const result = checkCustomerHasSufficientFundsForCharge(customer, 5_000)
    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error.kind).toBe('INSUFFICIENT_FUNDS')
      expect(result.error.available).toBe(4_999)
      expect(result.error.required).toBe(5_000)
    }
  })
})

// ── Full Charge Approval Flow ─────────────────────────────────────────────────
describe('assembled charge approval (all rules combined)', () => {
  it('should_approve_charge_when_all_billing_conditions_are_satisfied', () => {
    const customer = aCustomerWithSufficientFunds()
    const result = assembleApprovedChargeForCustomer(customer, 1_000)
    expect(result.success).toBe(true)
  })

  it('should_fail_at_amount_validation_before_checking_payment_method', () => {
    const customer = aCustomerWithSufficientFunds()
    const result = assembleApprovedChargeForCustomer(customer, 10) // below minimum
    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error.kind).toBe('CHARGE_AMOUNT_INVALID')
    }
  })

  it('should_fail_at_payment_method_check_before_checking_funds', () => {
    const customer = aCustomerWithExpiredPaymentMethod()
    const result = assembleApprovedChargeForCustomer(customer, 1_000)
    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error.kind).toBe('PAYMENT_METHOD_EXPIRED')
    }
  })
})
```

---

## Fixture Builder Pattern

Never create ad-hoc test objects inline — they clutter the test and hide intent.
Use **named builder functions** that return sensible defaults with optional overrides.

```typescript
// ✅ Fixture builders make tests self-describing
const aVerifiedCustomerWithActiveSubscription = (overrides?: Partial<Customer>): Customer => ({
  id: 'cust-' + Math.random(),
  emailVerifiedAt: new Date('2024-01-01'),
  subscriptionStatus: 'ACTIVE',
  tier: 'STANDARD',
  ...overrides,
})

const aVIPCustomerEligibleForDiscount = (): Customer =>
  aVerifiedCustomerWithActiveSubscription({ tier: 'VIP' })

// Usage in tests — reads like English
it('should_apply_15_percent_discount_when_customer_is_vip_tier', () => {
  const vipCustomer = aVIPCustomerEligibleForDiscount()
  const result = calculateDiscountForCustomer(vipCustomer, orderTotal)
  expect(result.discountPercentage).toBe(15)
})

// ❌ Inline object — hides intent, which fields matter?
it('discount_test', () => {
  const customer = { id: '1', email: 'a@b.com', tier: 'VIP', verified: true, active: true }
  const result = calculateDiscountForCustomer(customer, 100)
  expect(result.discountPercentage).toBe(15)
})
```

---

## Service Layer Testing — Using Fake Adapters

Test the service layer by injecting simple fake functions instead of real infrastructure.
No mock libraries needed — a plain function is the best fake.

```typescript
// src/billing/billing.service.test.ts
import { describe, it, expect, vi } from 'vitest'
import { chargeCustomerForOrderTotal } from './billing.service.ts'
import { ok, err } from '../shared/result.ts'
import type { FindCustomerById, SaveChargeReceipt } from './billing.repo.ts'
import type { Customer } from './billing.domain.ts'

// Fake adapters — simple functions that return controlled Results
const aFindCustomerThatAlwaysSucceeds = (customer: Customer): FindCustomerById =>
  async (_id) => ok(customer)

const aFindCustomerThatReturnsNotFound = (): FindCustomerById =>
  async (id) => err({ kind: 'CUSTOMER_NOT_FOUND', customerId: id })

const aSaveReceiptThatAlwaysSucceeds = (): SaveChargeReceipt =>
  async (receipt) => ok(receipt)

// Tests
describe('charge customer for order total (service)', () => {
  it('should_create_and_save_charge_receipt_when_all_conditions_are_met', async () => {
    const customer: Customer = {
      id: 'cust-1',
      balanceInCents: 50_000,
      paymentMethodExpiresAt: new Date('2099-01-01'),
    }

    const result = await chargeCustomerForOrderTotal(
      'cust-1',
      10_000,
      aFindCustomerThatAlwaysSucceeds(customer),
      aSaveReceiptThatAlwaysSucceeds(),
    )

    expect(result.success).toBe(true)
    if (result.success) {
      expect(result.value.customerId).toBe('cust-1')
      expect(result.value.amountChargedInCents).toBe(10_000)
    }
  })

  it('should_fail_with_customer_not_found_error_when_customer_does_not_exist', async () => {
    const result = await chargeCustomerForOrderTotal(
      'nonexistent-id',
      10_000,
      aFindCustomerThatReturnsNotFound(),
      aSaveReceiptThatAlwaysSucceeds(),
    )

    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error.kind).toBe('CUSTOMER_NOT_FOUND')
    }
  })
})
```

---

## What to Test vs What to Skip

| Test this ✅ | Skip this ❌ |
|---|---|
| Every business rule in `*.domain.ts` | The TypeScript types themselves |
| Every service orchestration path in `*.service.ts` | Database migrations |
| Every error case (not just happy path) | Infrastructure adapters (test with integration tests) |
| Boundary conditions (exactly at min/max) | HTTP routing (test with e2e tests) |
| Railway flow (does error propagate correctly?) | Framework boilerplate |
| Fixture edge cases | Private implementation details |

---

## Vitest Configuration for Domain Tests

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // Pattern: all .test.ts files in src/
    include: ['src/**/*.test.ts'],
    // Exclude integration and e2e tests from unit test run
    exclude: ['src/**/*.integration.test.ts', 'src/**/*.e2e.test.ts'],
    // Tests should be fast — if a domain test takes >100ms, something is wrong
    testTimeout: 1000,
  },
})
```

Run with: `bun test` or `bunx vitest run`

---

## The TDD Rhythm (Red-Green-Refactor)

1. **Red:** Write the test first. It fails because the function doesn't exist yet.
   The test name becomes your contract: "I need a function that does X when Y."

2. **Green:** Write the simplest possible implementation that makes the test pass.
   Don't over-engineer. Don't think about edge cases yet.

3. **Refactor:** Clean up the implementation. Remove duplication. Apply Storyteller naming.
   The tests protect you — if they still pass, the refactor is safe.

4. **Repeat:** Add the next test case (the next business rule), go red again.

This rhythm ensures every line of production code exists because a business rule requires it.
No speculative code. No "we might need this later" abstractions.
