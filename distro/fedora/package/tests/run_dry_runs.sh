#!/usr/bin/env bash
set -Eeuo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
readonly C_PRIMARY="#00BFFF"
readonly C_SUCCESS="#04B575"
readonly C_WARNING="#FFA500"
readonly C_DANGER="#FF4500"

# ── LAYER 1: UI PRIMITIVES ──────────────────────────────────────────────────
banner() {
  gum style --border double --border-foreground "$C_PRIMARY" --align center --padding "1 4" --bold "$*"
}

step() {
  gum style --foreground "$C_PRIMARY" --bold "▶  Testing: ${1}"
}

ok() {
  gum style --foreground "$C_SUCCESS" "  ✔  $*"
}

fail() {
  gum style --border thick --border-foreground "$C_DANGER" --foreground "$C_DANGER" --bold --padding "0 2" "✖  TEST FAILED: $*"
  exit 1
}

# ── MAIN ────────────────────────────────────────────────────────────────────
main() {
  banner "RUNNING DRY-RUN TESTS"
  
  # Find all .sh files in current directory, excluding tests folder
  local scripts
  scripts=$(find . -maxdepth 2 -name "*.sh" -not -path "*/tests/*")
  
  for script in $scripts; do
    step "$(basename "$script")"
    
    # Run in dry run mode
    if DRY_RUN=1 bash "$script"; then
      ok "Dry run passed for $(basename "$script")"
    else
      fail "Dry run failed for $(basename "$script")"
    fi
  done
  
  gum style --foreground "$C_SUCCESS" --bold "\n🎉 All dry-run tests passed!"
}

main "$@"
