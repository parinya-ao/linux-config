# Reference 02 — Storyteller Naming Conventions

## The Core Rule

Every function and variable name must answer: **"What does this do in the business?"**
Not "what does this do technically." Read the name aloud. Does it sound like something
a business person would say? If yes, it's a good name.

```
Good test: "We need to [function name]" → "We need to verifyCustomerIsEligibleForVIPDiscount"
Bad test:  "We need to [function name]" → "We need to processData" ← what data? process how?
```

---

## Function Naming Patterns

Functions should read as **imperative verb phrases** or **questions**:

| Pattern | Template | Example |
|---|---|---|
| Command (does something) | `verb + Noun` | `cancelOrder()` |
| Query (returns boolean) | `checkIf/verify + Condition` | `checkIfCustomerIsEligibleForDiscount()` |
| Query (returns data) | `find/get/load + Subject` | `findCustomerByEmail()` |
| Transformation | `convert/calculate/build + Target` | `calculateDiscountedPriceForVIPCustomer()` |
| Validation | `validate + Subject + Condition` | `validateOrderHasAtLeastOneLineItem()` |
| Assembly | `assemble/prepare/compose + Subject` | `assembleInvoiceFromOrderLineItems()` |

**Verb vocabulary by operation type:**

- **Create:** `create`, `register`, `place`, `open`, `start`, `initiate`
- **Read:** `find`, `get`, `load`, `fetch`, `retrieve`, `list`, `search`
- **Update:** `update`, `modify`, `change`, `apply`, `set`, `mark`
- **Delete:** `cancel`, `remove`, `deactivate`, `archive`, `close`
- **Verify:** `check`, `verify`, `validate`, `confirm`, `ensure`
- **Transform:** `convert`, `calculate`, `build`, `assemble`, `prepare`
- **Approve:** `approve`, `authorize`, `grant`, `allow`, `permit`
- **Reject:** `reject`, `deny`, `block`, `refuse`, `revoke`

---

## Variable Naming Patterns

Variables should name **what the value represents in the domain**, not what type it is.

```typescript
// ❌ Technical names (what type is it)
const data    = await db.find(id)
const result  = validateInput(payload)
const list    = getAll()
const flag    = customer.verified

// ✅ Storyteller names (what it IS in the business)
const customer                         = await findCustomerById(customerId)
const emailValidationResult            = validateCustomerEmailFormat(payload.email)
const activeOrdersForThisCustomer      = listActiveOrdersByCustomerId(customerId)
const isCustomerVerifiedForCheckout    = customer.emailVerifiedAt !== null
```

**For boolean variables, always use `is`, `has`, `can`, `should`:**
```typescript
const isCustomerEligibleForDiscount    = tier === 'VIP'
const hasOrderExceededFreeShippingLimit = orderTotal > FREE_SHIPPING_THRESHOLD
const canCustomerAccessPremiumContent  = subscription.status === 'ACTIVE'
const shouldApplyLateDeliveryPenalty   = deliveryDate > promisedDeliveryDate
```

---

## Domain-Specific Vocabulary Guide

When naming, match the vocabulary of the business domain. Use the terms that domain experts
(product managers, business analysts) actually use — not programmer slang.

### Order Domain
```typescript
// Actions
placeOrder()            // customer creates an order
confirmOrder()          // system confirms order is ready to fulfill
fulfillOrder()          // warehouse starts packing
shipOrder()             // order leaves the warehouse
deliverOrder()          // order arrives at customer
cancelOrder()           // order is cancelled before shipping
returnOrder()           // customer sends order back
refundOrderTotal()      // money goes back to customer

// Queries
findOrderByTrackingNumber()
listUnfulfilledOrdersOlderThanOneDay()
checkIfOrderIsEligibleForFreeShipping()
calculateEstimatedDeliveryDateForOrder()

// Types
Order, OrderLineItem, ShippingAddress, TrackingNumber, FulfillmentStatus
```

### Billing Domain
```typescript
// Actions
chargeCustomerForOrderTotal()
issueRefundForCancelledOrder()
applyDiscountCodeToOrder()
upgradeCustomerSubscriptionTier()
renewCustomerSubscriptionOnExpiryDate()
suspendCustomerAccountForNonPayment()

// Queries
findUnpaidInvoicesForCustomer()
calculateTotalOutstandingBalanceForCustomer()
checkIfCustomerHasSufficientFundsForCharge()
checkIfDiscountCodeIsStillValid()

// Types
Invoice, PaymentMethod, ChargeReceipt, DiscountCode, SubscriptionTier
```

### Auth Domain
```typescript
// Actions
registerNewCustomerWithEmailAndPassword()
authenticateCustomerWithEmailPassword()
sendEmailVerificationLink()
verifyCustomerEmailWithToken()
revokeAllActiveSessionsForCustomer()
requestPasswordReset()
resetPasswordWithValidToken()
refreshSessionToken()

// Queries
checkIfEmailIsAlreadyRegistered()
checkIfPasswordResetTokenIsStillValid()
findActiveSessionByToken()
checkIfCustomerHasPermissionToAccessResource()

// Types
Session, PasswordResetToken, EmailVerificationToken, Permission
```

### Inventory Domain
```typescript
// Actions
reserveInventoryForOrder()
releaseReservedInventoryForCancelledOrder()
replenishInventoryForSku()
markSkuAsDiscontinued()

// Queries
checkIfSkuHasSufficientInventoryForOrder()
findSkusWithInventoryBelowReorderThreshold()
calculateAvailableInventoryExcludingReservations()

// Types
Sku, InventoryReservation, StockLevel, ReorderThreshold
```

---

## Transformation Table — Bad → Good

| ❌ Bad Name | ✅ Good Name | Why |
|---|---|---|
| `process()` | `fulfillCustomerOrder()` | "Process" says nothing about the business |
| `handleRequest()` | `handlePlaceOrderRequest()` | What kind of request? |
| `updateUser()` | `deactivateCustomerAccount()` | Update what? The name hides the business change |
| `getItem()` | `findOrderLineItemBySku()` | What item? From where? |
| `validate()` | `validateCartHasAtLeastOneItem()` | Validate what rule? |
| `check()` | `checkIfCustomerEmailIsVerified()` | Check what condition? |
| `calculate()` | `calculateShippingCostForInternationalOrder()` | Calculate what? |
| `send()` | `sendOrderConfirmationEmailToCustomer()` | Send what to whom? |
| `run()` | `runDailyBillingCycleForAllActiveSubscriptions()` | Run what? |
| `doStuff()` | _never exists in production code_ | |
| `temp`/`tmp` | `temporaryOrderDraftBeforePaymentConfirmation` | Even temporaries need names |
| `data` | `customerWithUnpaidInvoices` | Data is always "data" — name the shape |
| `res` | `createdOrderResponse` | What response? |
| `e` in catch | `billingError` | Name the domain of the error |
| `cb` | `onChargeSuccessful` | Callbacks describe their trigger |
| `i`, `j` in loops | `orderIndex`, `lineItemIndex` | Loop variables name their subject |
| `arr` | `pendingOrdersForProcessing` | Arrays name their contents |
| `obj` | `customerBillingProfile` | Objects name their concept |
| `isValid` | `isShippingAddressComplete` | Valid according to what rule? |
| `status` | `orderFulfillmentStatus` | Status of what? |
| `type` | `customerSubscriptionTier` | Type of what? |
| `config` | `stripePaymentGatewayConfig` | Config for what service? |
| `helper` | _never exists in production code_ | Helpers have real names |
| `util` | _never exists in production code_ | Utils have real names |
| `manager` | _never exists in production code_ | Managers manage what, exactly? |
| `handler` | `handleCustomerCheckoutRequest` | Handlers name what they handle |

---

## File Naming Conventions

Files should also scream their purpose:

```
billing.domain.ts       ← Pure business rules for billing
billing.errors.ts       ← Error union types for billing domain
billing.repo.ts         ← Port interface (what the domain needs from the DB)
billing.postgres-repo.ts ← Adapter (Postgres implementation of the port)
billing.service.ts      ← Orchestrates domain + ports
billing.http.ts         ← HTTP adapter (routes + request handlers)
billing.test.ts         ← Living documentation for billing domain
```

Never name files: `utils.ts`, `helpers.ts`, `common.ts`, `misc.ts`, `index.ts` (except for
barrel exports), or `types.ts` (unless it contains truly shared types across many domains).

---

## The Smell Test

Read your code out loud to a rubber duck. If you stumble, sound confused, or would need to
explain what it means — it needs a better name. Good code reads like a business story:

```typescript
// Read this aloud — it tells the complete business story
const customer = await findCustomerById(customerId)
if (!customer.success) return customer

const isCustomerEligibleForCheckout = checkIfCustomerEmailIsVerified(customer.value)
if (!isCustomerEligibleForCheckout.success) return isCustomerEligibleForCheckout

const availableInventory = await checkIfSkuHasSufficientInventoryForOrder(cart)
if (!availableInventory.success) return availableInventory

const reservedInventory = await reserveInventoryForOrder(cart, orderId)
if (!reservedInventory.success) return reservedInventory

const chargeReceipt = await chargeCustomerForOrderTotal(customer.value, cart.totalInCents)
if (!chargeReceipt.success) return chargeReceipt

return confirmOrderAndSendConfirmationEmail(orderId, chargeReceipt.value)
```

This reads like a business specification. No comments needed.
