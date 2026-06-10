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
LOG_FILE="/tmp/firefox_dev_install_${TARGET_USER}.log"

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
assert_environment() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "DRY RUN: Skipping prerequisite checks."
    return 0
  fi
  
  if ! command -v dnf >/dev/null 2>&1; then
    fail "'dnf' missing. Not Fedora."
  fi
  
  if ! sudo -v >/dev/null 2>&1; then
    fail "No sudo privileges."
  fi
}

purge_deprecated_copr() {
  if rpm -q firefox-dev >/dev/null 2>&1; then
    run_step line "Removing legacy COPR package" sudo dnf remove -y firefox-dev
  fi
  run_step points "Disabling legacy COPR repo" sudo dnf copr disable -y the4runner/firefox-dev
}

synchronize_base_metadata() {
  run_step points "Refreshing metadata" sudo dnf upgrade --refresh -y --downloadonly
}

inject_mozilla_repository() {
  run_step globe "Adding Mozilla repository" sudo dnf config-manager addrepo \
    --id=mozilla \
    --set=baseurl=https://packages.mozilla.org/rpm/firefox \
    --set=gpgkey=https://packages.mozilla.org/rpm/firefox/signing-key.gpg \
    --set=gpgcheck=1 \
    --set=repo_gpgcheck=0 \
    --set=priority=10 \
    --set=includepkgs=firefox-devedition\*
}

refresh_target_cache() {
  run_step points "Caching Mozilla repo" sudo dnf makecache --refresh --repo mozilla
}

execute_package_provisioning() {
  run_step line "Installing Firefox DevEdition" sudo dnf install -y firefox-devedition
}

verify_operational_integrity() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "DRY RUN: Skipping verification."
    return 0
  fi
  
  if command -v firefox-devedition >/dev/null 2>&1; then
    ok "Firefox DevEdition version: $(firefox-devedition --version 2>/dev/null)"
  else
    fail "Binary not found in PATH."
  fi
}

# ── LAYER 4: ORCHESTRATION ──────────────────────────────────────────────────
main() {
  touch "$LOG_FILE"
  trap 'fail "Unexpected failure at line $LINENO"' ERR
  
  banner "FIREFOX DEV INSTALLER"
  
  local PIPELINE=(
    "assert_environment"
    "purge_deprecated_copr"
    "synchronize_base_metadata"
    "inject_mozilla_repository"
    "refresh_target_cache"
    "execute_package_provisioning"
    "verify_operational_integrity"
  )
  
  local step_num=1
  for task in "${PIPELINE[@]}"; do
    step "$step_num" "$task"
    "$task"
    (( step_num++ ))
  done
  
  gum style --foreground "$C_SUCCESS" --bold "\n🎉 Firefox Dev setup complete!"
}

main "$@"
