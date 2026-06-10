#!/usr/bin/env bash
set -Eeuo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
readonly C_PRIMARY="#00BFFF"
readonly C_SUCCESS="#04B575"
readonly C_MUTED="#666666"

# ── LAYER 1: UI PRIMITIVES ──────────────────────────────────────────────────
ok() { gum style --foreground "$C_SUCCESS" "  ✔  $*"; }
info() { gum style --foreground "$C_MUTED" "  ℹ  $*"; }

# ── LAYER 2: RUNNER HELPER ──────────────────────────────────────────────────
run_step() {
  local spinner="$1" title="$2"
  shift 2
  if gum spin --spinner "$spinner" --title "  ${title}..." -- "$@"; then
    ok "$title"
  else
    exit 1
  fi
}

# ── LAYER 3: TASK FUNCTIONS ──────────────────────────────────────────────────
install_ansible() {
  info "Installing Ansible dev tools..."
  run_step line "Installing python3-pip" sudo dnf install -y python3-pip
  run_step dot "Installing ansible-dev-tools via pip" sudo pip3 install ansible-dev-tools ansible-creator
  ok "Ansible installed."
}

# ── LAYER 4: ORCHESTRATION ──────────────────────────────────────────────────
main() {
  install_ansible
}

main "$@"
