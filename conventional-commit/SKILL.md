---
name: conventional-commit
description: |
  Enforces Conventional Commits specification (v1.0.0) for git commits.
  Use this skill to guide commit message structure and type selection.
---

# Conventional Commits Skill

When creating a commit:

1. Run `git status` and `git diff --staged` to analyze changes.
2. Choose the correct type: feat, fix, docs, style, refactor, perf, test, build, ci, chore.
3. Add scope in parentheses if relevant: feat(api):
4. Add

```
<type>[(scope)][!]: <description>

[optional body]

[optional footer(s)]
```

The header (first line) is mandatory.

## Commit Types

| Type | Purpose | SemVer Impact |
|---|---|---|
| `feat` | A new feature | MINOR |
| `fix` | A bug fix | PATCH |
| `docs` | Documentation only | None |
| `style` | Formatting, whitespace | None |
| `refactor` | No bug fix or feature | None |
| `perf` | Performance improvement | None |
| `test` | Add/update tests | None |
| `build` | Build system/deps changes | None |
| `ci` | CI config changes | None |
| `chore` | Maintenance tasks | None |
| `revert` | Reverts a prior commit | Varies |

Breaking changes (any type with `BREAKING CHANGE:` footer) trigger a **MAJOR** release.

## Rules

- Lowercase type and description
- Imperative mood: "add" not "added"
- No period at end
- Header ≤ 72 characters (ideally ≤ 50)
- Body wraps at 72 characters per line
- Blank line between header, body, and footer
- BREAKING CHANGE must also use

```
feat(auth): add OAuth2 login support
fix(api): handle null values in JSON response
docs(readme): update installation instructions
```

Common scopes: auth, api, ui, db, config, ci, deps, services.

## Breaking Change Example

```
feat(api)!: redesign user authentication endpoints

The authentication flow now uses JWT tokens instead of session cookies.

BREAKING CHANGE: POST /auth/login returns a JWT token in the response body.
Clients must include the token in the Authorization header.
Refs: #456
```

## Footer References

```
fix(auth): resolve session timeout bug

Fixes #123
Closes #456
Co-authored-by: Jane Doe <jane@example.com>
```

## SemVer Mapping

- `fix` → PATCH (0.0.X)
- `feat` → MINOR (0.X.0)
- BREAKING CHANGE / `@commitlint/config-conventional` — validates messages via git hook
- **Husky** — runs commitlint as a `commit-msg` hook
- **release-please** / **semantic-release** — auto-changelog based on types
- **`git log --grep="^feat"`** — filter history by type
