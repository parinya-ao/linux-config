---
name: code-comments
description: >
  Expert guide for writing clean, professional code comments following Google Style Guide philosophy.
  Use this skill whenever the user asks to: write, review, or improve code comments or documentation;
  add inline comments to code; check whether comments are necessary or redundant; write TODO comments;
  teach or explain commenting best practices; audit code for comment quality; or when writing any code
  in any language (Python, TypeScript, JavaScript, Go, Java, C++, Rust, etc.) that requires inline
  comments. Also trigger when user mentions "comment", "คอมเมนต์", "why this code", "self-documenting",
  "TODO", "code documentation", "clean code", or asks to explain what a piece of code does.
  This skill enforces 3 core mantras — What/Why separation, Self-Documenting Naming, and Hack Documentation.
  Always apply these mantras even when the user doesn't explicitly ask for comment review.
---

# Code Comments Skill

## Core Philosophy (Google Style Guide — All Languages)

The best code is code that explains itself — with minimal comments.

> **"Code tells How/What. Comments tell Why."**

This principle is shared across every Google Style Guide (Python, TypeScript, JavaScript, Go, Java, C++).
A comment that restates what the code already says is noise. A comment that explains *why* the code does something unusual is gold.

---

## The 3 Mantras

### Mantra 1: Code tells What — Comments tell Why

The most common mistake is writing *redundant comments* that describe what the code visibly does.
These add clutter without adding information.

**❌ Bad (restates What the code does):**
```python
# Check if age is greater than or equal to 18
if age >= 18:
    ...
```

**✓ Good (explains Why this threshold exists):**
```python
# Thai law requires users to be 18+ for this financial transaction
if age >= 18:
    ...
```

**Rule of thumb:** If someone reading the comment already knows the language, and the comment tells them nothing new, delete it.

---

### Mantra 2: Don't use comments to fix bad naming — rename instead

If you feel the urge to write a comment explaining what a variable or function *is*, that's a signal the name is wrong.
Google calls this **Self-Documenting Code** — the code itself should be clear enough that no comment is needed.

**❌ Bad (comment compensates for a bad name):**
```python
# The date when the customer's software license started
d = datetime.now()
```

**✓ Good (no comment needed — name says everything):**
```python
software_license_start_date = datetime.now()
```

The fix is always: delete the comment, rename the variable/function to be descriptive.

**Same principle applies to functions:**

```typescript
// ❌ Bad
// Get user data from cache or fetch from API if expired
function getData(id: string) { ... }

// ✓ Good — no comment needed
function getUserFromCacheOrFetch(userId: string) { ... }
```

---

### Mantra 3: Comment only the unusual — Hacks, Edge Cases, Tricks

Normal code following standard patterns needs no comment.
But when code looks strange, bends a rule, or requires special knowledge to understand — **you must comment.**

This includes:
- Working around a bug in a third-party library
- Handling a weird edge case from business logic
- Using a non-obvious algorithm for performance reasons
- Intentionally doing something that looks wrong but is correct

**✓ Production-grade examples:**

```go
// Using linear search here instead of binary search because real data
// has at most 5 items — linear is faster due to CPU cache locality on small arrays.
for _, item := range shortList { ... }
```

```typescript
// Stripe webhook events can arrive out of order; we process idempotently
// and ignore events older than the current state rather than erroring.
if (event.created < currentState.updatedAt) return;
```

```python
# time.sleep(0.1) — not a bug. The upstream API has an undocumented
# rate limit of ~10 req/s; this keeps us safely under it.
time.sleep(0.1)
```

---

## Format Standards (All Languages)

### 1. Always space after the comment symbol

```python
# ✓ Readable
#❌ Cramped — avoid this
```

```typescript
// ✓ Readable
//❌ Cramped — avoid this
```

This applies to `//`, `#`, `--`, `%`, `;`, and any other comment marker.

### 2. TODO format — always include the owner

A TODO without an owner is a TODO that never gets done.
Google requires every TODO to name who will fix it, in parentheses.

```
// TODO(username): description of what needs to be done
```

**❌ Bad (no owner — will be ignored forever):**
```python
# TODO: fix this later
```

**✓ Good (clear owner and reason):**
```python
# TODO(somchai): Switch to API v2 once v1 is deprecated next month
```

```typescript
// TODO(parinya): Remove this workaround after upgrading to Zod 4
```

The name in parentheses can be a username, GitHub handle, or nickname — whatever identifies the person in your team's system.

---

## Quick Reference Cheat Sheet

| Situation | Action |
|:---|:---|
| Code reads clearly on first pass | 🛑 **No comment** — clean code speaks for itself |
| Variable/function needs a comment to explain what it is | 🛑 **No comment** — rename it to be self-describing |
| Using a non-obvious approach due to business rule or constraint | ✅ **Comment required** — explain the Why |
| Working around a library bug or external limitation | ✅ **Comment required** — explain what and why |
| Optimizing with a non-standard algorithm for performance | ✅ **Comment required** — explain the trade-off |
| Work-in-progress or known technical debt | ✅ **TODO(owner): description** |

---

## Language-Specific Notes

These mantras apply universally. Minor syntax differences:

| Language | Single-line | Multi-line / Docstring |
|:---|:---|:---|
| Python | `# comment` | `"""docstring"""` |
| TypeScript / JavaScript | `// comment` | `/** JSDoc */` |
| Go | `// comment` | `/* block */` |
| Java | `// comment` | `/** Javadoc */` |
| C++ | `// comment` | `/* block */` |
| Rust | `// comment` | `/// doc comment` |
| Bash | `# comment` | — |

For **function/method docstrings** (JSDoc, Pydoc, Godoc): document the *contract* — what parameters mean, what's returned, and any non-obvious preconditions. Skip restating what the function name already says.

---

## Applying This Skill

When writing or reviewing code, always check each comment against the 3 mantras:

1. **Does this comment say Why, or just What?** — If only What, delete it.
2. **Could I rename something instead of adding this comment?** — If yes, rename.
3. **Is this code unusual enough to need an explanation?** — If yes, write a Why comment.

When adding a TODO, always include the owner name.
When in doubt about whether to comment — lean toward no comment and a better name instead.
