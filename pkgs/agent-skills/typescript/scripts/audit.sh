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
command -v bun &>/dev/null && pass "bun installed ($(bun --version))" || fail "bun not installed"
[ -f "bun.lockb" ] || [ -f "bun.lock" ] && pass "bun lockfile present" || fail "no bun lockfile (is this a bun project?)"

# ── package.json ──────────────────────────
echo ""
echo "package.json"
[ -f "package.json" ] && pass "package.json exists" || fail "no package.json"

check_dep() {
  local pkg="$1"
  local is_dev="${2:-}"
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
[ -f "tsconfig.json" ] && pass "tsconfig.json" || fail "tsconfig.json missing"

if [ -f "tsconfig.json" ]; then
  grep -q '"@/\*"' tsconfig.json && pass "  → path alias @/ configured" || fail "  → path alias @/ NOT configured in tsconfig"
  grep -q '"strict": true' tsconfig.json && pass "  → strict mode on" || warn "  → strict mode not explicitly enabled"
fi

[ -f ".editorconfig" ] && pass ".editorconfig" || fail ".editorconfig missing"
[ -f ".prettierrc" ] || [ -f ".prettierrc.json" ] && pass ".prettierrc" || fail ".prettierrc missing"
[ -f ".prettierignore" ] && pass ".prettierignore" || warn ".prettierignore missing (optional but recommended)"
[ -f "eslint.config.mjs" ] || [ -f "eslint.config.js" ] && pass "eslint.config (flat)" || \
  ([ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] && warn "legacy .eslintrc found (consider migrating to flat config)" || fail "no ESLint config")

[ -f "vitest.config.ts" ] && pass "vitest.config.ts" || fail "vitest.config.ts missing"
[ -f "playwright.config.ts" ] && pass "playwright.config.ts" || fail "playwright.config.ts missing"
[ -f "commitlint.config.ts" ] && pass "commitlint.config.ts" || fail "commitlint.config.ts missing"
[ -f ".versionrc.json" ] && pass ".versionrc.json" || fail ".versionrc.json missing"

# ── Husky ────────────────────────────────
echo ""
echo "Git hooks (Husky)"
[ -d ".husky" ] && pass ".husky directory" || fail ".husky not initialised"
[ -f ".husky/pre-commit" ] && pass "pre-commit hook" || fail "pre-commit hook missing"
[ -f ".husky/commit-msg" ] && pass "commit-msg hook" || fail "commit-msg hook missing"

# ── Source layout ─────────────────────────
echo ""
echo "Source layout"
[ -d "src" ] && pass "src/ directory" || fail "src/ directory missing"
[ -f "src/env.ts" ] && pass "src/env.ts (t3-env)" || warn "src/env.ts not found — create env schema"
[ -f "src/lib/logger.ts" ] && pass "src/lib/logger.ts" || warn "src/lib/logger.ts not found — create pino singleton"
[ -f "src/lib/http.ts" ] && pass "src/lib/http.ts" || warn "src/lib/http.ts not found — create got wrapper"
[ -d "src/schemas" ] && pass "src/schemas/" || warn "src/schemas/ not found — create Zod schemas directory"
[ -d "tests/unit" ] && pass "tests/unit/" || warn "tests/unit/ not found"
[ -d "tests/e2e" ] && pass "tests/e2e/" || warn "tests/e2e/ not found"

# ── Scripts ──────────────────────────────
echo ""
echo "package.json scripts"
if [ -f "package.json" ]; then
  grep -q '"lint"' package.json     && pass "lint script"     || fail "lint script missing"
  grep -q '"typecheck"' package.json && pass "typecheck script" || fail "typecheck script missing"
  grep -q '"test"' package.json     && pass "test script"     || fail "test script missing"
  grep -q '"test:e2e"' package.json && pass "test:e2e script" || fail "test:e2e script missing"
  grep -q '"release"' package.json  && pass "release script"  || fail "release script missing"
fi

echo ""
echo "══════════════════════════════════════"
echo "  Audit complete."
echo "  ✗ items = missing tooling to add"
echo "  ~ items = optional / informational"
echo "══════════════════════════════════════"
echo ""
