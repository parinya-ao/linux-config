#!/usr/bin/env bash
set -Eeuo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
readonly SCRIPT_DIR
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd -P)"

# Expected skill sources in pkgs/agent-skills/
readonly EXPECTED_SKILL_SRCS=(
  conventional-commit
  gum-bash
  nix-config
  recall
  recap
  remember
)

# Expected list in modules/programs/agent-skills.nix
readonly EXPECTED_HM_LIST=(
  conventional-commit
  gum-bash
  nix-config
  recall
  recap
  remember
)

# Expected list in share/install-agent-skills.sh
readonly EXPECTED_INSTALL_LIST=(
  conventional-commit
  gum-bash
  nix-config
  recall
  recap
  remember
)

# ── CHECKS ──────────────────────────────────────────────────────────────────

failures=0

check_skill_src() {
  local name="$1"
  local dir="$REPO_ROOT/pkgs/agent-skills/$name"
  if [[ -d "$dir" && -f "$dir/SKILL.md" ]]; then
    local size
    size=$(wc -c < "$dir/SKILL.md")
    echo "  ✓ source $name ($size bytes)"
  else
    echo "  ✗ source $name — missing SKILL.md"
    return 1
  fi
}

check_hm_module() {
  local name="$1"
  local file="$REPO_ROOT/modules/programs/agent-skills.nix"
  if grep -q "\"$name\"" "$file" 2>/dev/null; then
    echo "  ✓ HM module has $name"
  else
    echo "  ✗ HM module missing $name"
    return 1
  fi
}

check_install_script() {
  local name="$1"
  local file="$REPO_ROOT/share/install-agent-skills.sh"
  if grep -q "$name" "$file" 2>/dev/null; then
    echo "  ✓ install script has $name"
  else
    echo "  ✗ install script missing $name"
    return 1
  fi
}

check_derivation() {
  local name="$1"
  local file="$REPO_ROOT/pkgs/agent-skills/default.nix"
  if grep -q "$name" "$file" 2>/dev/null; then
    echo "  ✓ derivation has $name"
  else
    echo "  ✗ derivation missing $name"
    return 1
  fi
}

# ── MAIN ────────────────────────────────────────────────────────────────────

echo "=== Verifying Agent Skills Consistency ==="
echo ""

for skill in "${EXPECTED_SKILL_SRCS[@]}"; do
  check_skill_src "$skill" || ((failures++))
  check_derivation "$skill" || ((failures++))
  check_hm_module "$skill" || ((failures++))
  check_install_script "$skill" || ((failures++))
  echo ""
done

echo "=== Results: $failures failures ==="
exit "$failures"
