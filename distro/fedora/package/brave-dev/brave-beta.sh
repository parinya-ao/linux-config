#!/usr/bin/env bash
set -Eeuo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
readonly C_PRIMARY="#00BFFF"    # Deep Sky Blue
readonly C_SUCCESS="#04B575"    # Mint Green
readonly C_WARNING="#FFA500"    # Amber
readonly C_DANGER="#FF4500"     # Red-Orange
readonly C_MUTED="#666666"      # Dim Gray
readonly C_ACCENT="#C678DD"     # Soft Purple
readonly C_HIGHLIGHT="#98C379"  # Soft Green

export GUM_SPIN_SPINNER="line"
export GUM_LOG_LEVEL="info"
export GUM_LOG_TIME="rfc822"

LOG_FILE="/var/log/brave_install_debug.log"

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

kv() {
  local label value
  label=$(gum style --foreground "$C_MUTED" --width 14 "$1")
  value=$(gum style --foreground "$C_ACCENT" "$2")
  gum join --horizontal "$label" "$value"
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
check_root() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "DRY RUN: Skipping root check."
    return 0
  fi

  if [[ "$EUID" -ne 0 ]]; then
    fail "This script must be run as root."
  fi
}

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID=$ID
  else
    fail "Cannot detect OS."
  fi
}

install_dependencies() {
  if rpm -q dnf-plugins-core >/dev/null 2>&1; then
    info "dnf-plugins-core already installed, skipping."
    return 0
  fi
  run_step line "Installing dnf-plugins-core" dnf install -y dnf-plugins-core
}

configure_repository() {
  if dnf repolist | grep -qi "brave-browser-beta"; then
    info "Brave Beta repository already configured, skipping."
    return 0
  fi
  
  local REPO_URL="https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo"
  
  if [[ "$OS_ID" == "fedora" ]]; then
    run_step globe "Configuring repository" dnf config-manager addrepo --from-repofile="$REPO_URL"
  elif [[ "$OS_ID" =~ ^(rhel|rocky|almalinux|centos)$ ]]; then
    run_step globe "Configuring repository" dnf config-manager --add-repo "$REPO_URL"
  else
    fail "Unsupported OS: $OS_ID"
  fi
}

install_brave_beta() {
  if rpm -q brave-browser-beta >/dev/null 2>&1; then
    info "Brave Browser Beta already installed, skipping."
    return 0
  fi
  run_step line "Installing brave-browser-beta" dnf install -y brave-browser-beta
}

verify_installation() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "DRY RUN: Skipping verification."
    return 0
  fi
  
  if command -v brave-browser-beta >/dev/null 2>&1; then
    ok "Brave Browser Beta is installed: $(brave-browser-beta --version 2>/dev/null)"
  else
    fail "Binary not found in PATH."
  fi
}

# ── LAYER 4: ORCHESTRATION ──────────────────────────────────────────────────
show_summary() {
  local title
  title=$(gum style --foreground "$C_SUCCESS" --bold "🎉  INSTALLATION COMPLETE")
  
  local body
  body=$(gum join --vertical --align left "$title" "" "$(kv "Package" "Brave Beta")" "$(kv "Status" "Installed")")
  
  gum style --border rounded --border-foreground "$C_SUCCESS" --padding "1 3" "$body"
}

main() {
  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    touch "$LOG_FILE" || fail "Cannot write to log file."
  fi
  trap 'fail "Unexpected failure at line $LINENO"' ERR
  
  banner "BRAVE BETA INSTALLER"
  
  local PIPELINE=(
    "check_root"
    "detect_os"
    "install_dependencies"
    "configure_repository"
    "install_brave_beta"
    "verify_installation"
  )
  
  local step_num=1
  for task in "${PIPELINE[@]}"; do
    step "$step_num" "$task"
    "$task"
    (( step_num++ ))
  done
  
  show_summary
}

main "$@"
