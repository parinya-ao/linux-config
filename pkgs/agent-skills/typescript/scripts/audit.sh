#!/usr/bin/env bash
# scripts/audit.sh
# Run from project root: bash scripts/audit.sh
# Audits an existing project for missing ts-bun-stack tooling.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

pass() { echo -e "  ${GREEN}✓${RESET} $1"; }
fail() { echo -e "  ${RED}✗${RESET} $1"; }
warn() { echo -e "  ${YELLOW}~${RESET} $1"; }

echo ""
echo "══════════════════════════════════════"
echo "  ts-bun-stack Audit"
echo "══════════════════════════════════════"

# ── Runtime ──────────────────────────────
echo ""
echo "Runtime"
if command -v bun &>/dev/null; then
  pass "bun installed ($(bun --version))"
else
  fail "bun not installed"
fi
if [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
  pass "bun lockfile present"
else
  fail "no bun lockfile (is this a bun project?)"
fi

# ── package.json ──────────────────────────
echo ""
echo "package.json"
if [ -f "package.json" ]; then
  pass "package.json exists"
else
  fail "no package.json"
fi

check_dep() {
  local pkg="$1"
  if [ -f "package.json" ]; then
    if grep -q "\"$pkg\"" package.json; then
      pass "$pkg"
    else
      fail "$pkg missing"
    fi
  fi
}

echo ""
echo "  Production deps"
check_dep "pino"
check_dep "got"
check_dep "http-errors"
check_dep "zod"
check_dep "@t3-oss/env-core"

echo ""
echo "  Dev deps"
check_dep "pino-pretty"
check_dep "eslint"
check_dep "prettier"
check_dep "@typescript-eslint/parser"
check_dep "vitest"
check_dep "@playwright/test"
check_dep "husky"
check_dep "lint-staged"
check_dep "@commitlint/cli"
check_dep "@commitlint/config-conventional"
check_dep "standard-version"

# ── Config files ─────────────────────────
echo ""
echo "Config files"
if [ -f "tsconfig.json" ]; then
  pass "tsconfig.json"
else
  fail "tsconfig.json missing"
fi

if [ -f "tsconfig.json" ]; then
  if grep -q '"@/\*"' tsconfig.json; then
    pass "  → path alias @/ configured"
  else
    fail "  → path alias @/ NOT configured in tsconfig"
  fi
  if grep -q '"strict": true' tsconfig.json; then
    pass "  → strict mode on"
  else
    warn "  → strict mode not explicitly enabled"
  fi
fi

if [ -f ".editorconfig" ]; then
  pass ".editorconfig"
else
  fail ".editorconfig missing"
fi
if [ -f ".prettierrc" ] || [ -f ".prettierrc.json" ]; then
  pass ".prettierrc"
else
  fail ".prettierrc missing"
fi
if [ -f ".prettierignore" ]; then
  pass ".prettierignore"
else
  warn ".prettierignore missing (optional but recommended)"
fi
if [ -f "eslint.config.mjs" ] || [ -f "eslint.config.js" ]; then
  pass "eslint.config (flat)"
elif [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ]; then
  warn "legacy .eslintrc found (consider migrating to flat config)"
else
  fail "no ESLint config"
fi

if [ -f "vitest.config.ts" ]; then
  pass "vitest.config.ts"
else
  fail "vitest.config.ts missing"
fi
if [ -f "playwright.config.ts" ]; then
  pass "playwright.config.ts"
else
  fail "playwright.config.ts missing"
fi
if [ -f "commitlint.config.ts" ]; then
  pass "commitlint.config.ts"
else
  fail "commitlint.config.ts missing"
fi
if [ -f ".versionrc.json" ]; then
  pass ".versionrc.json"
else
  fail ".versionrc.json missing"
fi

# ── Husky ────────────────────────────────
echo ""
echo "Git hooks (Husky)"
if [ -d ".husky" ]; then
  pass ".husky directory"
else
  fail ".husky not initialised"
fi
if [ -f ".husky/pre-commit" ]; then
  pass "pre-commit hook"
else
  fail "pre-commit hook missing"
fi
if [ -f ".husky/commit-msg" ]; then
  pass "commit-msg hook"
else
  fail "commit-msg hook missing"
fi

# ── Source layout ─────────────────────────
echo ""
echo "Source layout"
if [ -d "src" ]; then
  pass "src/ directory"
else
  fail "src/ directory missing"
fi
if [ -f "src/env.ts" ]; then
  pass "src/env.ts (t3-env)"
else
  warn "src/env.ts not found — create env schema"
fi
if [ -f "src/lib/logger.ts" ]; then
  pass "src/lib/logger.ts"
else
  warn "src/lib/logger.ts not found — create pino singleton"
fi
if [ -f "src/lib/http.ts" ]; then
  pass "src/lib/http.ts"
else
  warn "src/lib/http.ts not found — create got wrapper"
fi
if [ -d "src/schemas" ]; then
  pass "src/schemas/"
else
  warn "src/schemas/ not found — create Zod schemas directory"
fi
if [ -d "tests/unit" ]; then
  pass "tests/unit/"
else
  warn "tests/unit/ not found"
fi
if [ -d "tests/e2e" ]; then
  pass "tests/e2e/"
else
  warn "tests/e2e/ not found"
fi

# ── Scripts ──────────────────────────────
echo ""
echo "package.json scripts"
if [ -f "package.json" ]; then
  if grep -q '"lint"' package.json; then
    pass "lint script"
  else
    fail "lint script missing"
  fi
  if grep -q '"typecheck"' package.json; then
    pass "typecheck script"
  else
    fail "typecheck script missing"
  fi
  if grep -q '"test"' package.json; then
    pass "test script"
  else
    fail "test script missing"
  fi
  if grep -q '"test:e2e"' package.json; then
    pass "test:e2e script"
  else
    fail "test:e2e script missing"
  fi
  if grep -q '"release"' package.json; then
    pass "release script"
  else
    fail "release script missing"
  fi
fi

echo ""
echo "══════════════════════════════════════"
echo "  Audit complete."
echo "  ✗ items = missing tooling to add"
echo "  ~ items = optional / informational"
echo "══════════════════════════════════════"
echo ""
