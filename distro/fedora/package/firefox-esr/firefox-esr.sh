#!/usr/bin/env bash
set -Eeuo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
readonly C_PRIMARY="#00BFFF"
readonly C_SUCCESS="#04B575"
readonly C_WARNING="#FFA500"
readonly C_DANGER="#FF4500"
readonly C_MUTED="#666666"

export GUM_SPIN_SPINNER="line"
export GUM_LOG_LEVEL="info"
export GUM_LOG_TIME="rfc822"

TARGET_USER="${SUDO_USER:-$USER}"
LOG_FILE="/tmp/firefox_esr_install_${TARGET_USER}.log"

# ── LAYER 1: UI PRIMITIVES ──────────────────────────────────────────────────
banner() {
  gum style --border double --border-foreground "$C_PRIMARY" --align center --padding "1 4" --bold "$*"
}

step() {
  gum style --foreground "$C_PRIMARY" --bold "▶  Step ${1}: ${2}"
}

ok() {
  gum style --foreground "$C_SUCCESS" "  ✔  $*"
}

warn() {
  gum style --foreground "$C_WARNING" "  ⚠  $*"
}

fail() {
  gum style --border thick --border-foreground "$C_DANGER" --foreground "$C_DANGER" --bold --padding "0 2" "✖  ERROR: $*"
  exit 1
}

info() {
  gum style --foreground "$C_MUTED" "  ℹ  $*"
}

# ── LAYER 2: RUNNER HELPER ──────────────────────────────────────────────────
run_step() {
  local spinner="$1" title="$2"
  shift 2
  
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "DRY RUN: $title (would execute: $*)"
    return 0
  fi

  if gum spin --spinner "$spinner" --title "  ${title}..." -- "$@"; then
    ok "$title"
  else
    local code=$?
    fail "$title (exit $code)"
  fi
}

# ── LAYER 3: TASK FUNCTIONS ──────────────────────────────────────────────────
check_privileges() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "DRY RUN: Skipping privilege check."
    return 0
  fi
  
  if [[ "$EUID" -ne 0 ]]; then
    fail "Must be run as root."
  fi
}

install_prerequisites() {
  if ! command -v dnf >/dev/null 2>&1; then
    fail "'dnf' missing. Not Fedora."
  fi
  run_step line "Installing prerequisites" sudo dnf install -y dnf-plugins-core
}

enable_copr_repo() {
  run_step globe "Enabling Copr repo (erizur/firefox-esr)" sudo dnf copr enable -y erizur/firefox-esr
}

install_package() {
  run_step line "Installing Firefox ESR" sudo dnf install -y firefox-esr
}

integration_test() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "DRY RUN: Skipping verification."
    return 0
  fi
  
  if command -v firefox-esr >/dev/null 2>&1; then
    ok "Firefox ESR version: $(firefox-esr --version 2>/dev/null)"
  else
    fail "Binary not found in PATH."
  fi
}

# ── LAYER 4: ORCHESTRATION ──────────────────────────────────────────────────
main() {
  touch "$LOG_FILE"
  trap 'fail "Unexpected failure at line $LINENO"' ERR
  
  banner "FIREFOX ESR INSTALLER"
  
  local PIPELINE=(
    "check_privileges"
    "install_prerequisites"
    "enable_copr_repo"
    "install_package"
    "integration_test"
  )
  
  local step_num=1
  for task in "${PIPELINE[@]}"; do
    step "$step_num" "$task"
    "$task"
    (( step_num++ ))
  done
  
  gum style --foreground "$C_SUCCESS" --bold "\n🎉 Firefox ESR setup complete!"
}

main "$@"
