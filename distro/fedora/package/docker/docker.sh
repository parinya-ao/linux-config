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
LOG_FILE="/tmp/docker_install_${TARGET_USER}.log"

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
check_prerequisites() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "DRY RUN: Skipping prerequisite checks."
    return 0
  fi

  if ! command -v dnf >/dev/null 2>&1; then
    fail "'dnf' not found. This script requires Fedora."
  fi
  
  if ! sudo -v >/dev/null 2>&1; then
    fail "Current user does not have sudo privileges."
  fi
}

remove_old_versions() {
  local packages=(docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine)
  run_step line "Removing old Docker packages" sudo dnf remove -y "${packages[@]}"
}

setup_repository() {
  run_step globe "Adding Docker repository" sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
}

install_docker_packages() {
  run_step line "Installing Docker packages" sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

configure_and_start_service() {
  run_step dot "Enabling Docker service" sudo systemctl enable --now docker
}

configure_user_group() {
  if grep -q "^docker:" /etc/group; then
    info "Docker group already exists."
  else
    run_step points "Creating Docker group" sudo groupadd docker
  fi
  run_step points "Adding $TARGET_USER to Docker group" sudo usermod -aG docker "$TARGET_USER"
}

# ── LAYER 4: ORCHESTRATION ──────────────────────────────────────────────────
main() {
  touch "$LOG_FILE"
  trap 'fail "Unexpected failure at line $LINENO"' ERR
  
  banner "DOCKER INSTALLER"
  
  local PIPELINE=(
    "check_prerequisites"
    "remove_old_versions"
    "setup_repository"
    "install_docker_packages"
    "configure_and_start_service"
    "configure_user_group"
  )
  
  local step_num=1
  for task in "${PIPELINE[@]}"; do
    step "$step_num" "$task"
    "$task"
    (( step_num++ ))
  done
  
  gum style --foreground "$C_SUCCESS" --bold "\n🎉 Docker setup complete!"
}

main "$@"
