#!/usr/bin/env bash
# =============================================================================
# package/docker.sh
# Docker Engine installer for openSUSE (Leap & Tumbleweed)
# Sourced by opensuse.sh — do not run directly.
# =============================================================================

install_docker() {
  # ── 1. Already installed? ────────────────────────────────────────────────
  if pkg_installed "docker"; then
    skip "Docker already installed"

    # Still make sure the service is running even on repeat runs
    if ! systemctl is-enabled docker &>/dev/null; then
      systemctl enable --now docker \
        && ok "Docker service enabled." \
        || warn "Could not enable Docker service — check manually."
    fi

    _docker_add_user
    return 0
  fi

  # ── 2. Install packages ──────────────────────────────────────────────────
  # Docker Engine ships in the standard openSUSE repositories.
  # docker-compose-switch provides the v2 compose subcommand.
  step "[Docker] Installing Docker Engine..."
  zypper_install \
    docker \
    docker-compose \
    docker-buildx

  # ── 3. Enable & start the daemon ─────────────────────────────────────────
  systemctl enable --now docker \
    && ok "docker.service enabled & started." \
    || warn "Failed to enable docker.service — try: sudo systemctl start docker"

  # ── 4. Add invoking user to docker group ─────────────────────────────────
  _docker_add_user

  ok "Docker Engine installed."
}

# ── Internal helper: add SUDO_USER to the docker group ─────────────────────
_docker_add_user() {
  local target_user="${SUDO_USER:-}"

  if [[ -z "$target_user" ]]; then
    warn "SUDO_USER not set — add yourself to the docker group manually:"
    warn "  sudo usermod -aG docker \$USER  (then log out & back in)"
    return 0
  fi

  if groups "$target_user" | grep -qw "docker"; then
    info "  ✓ '$target_user' is already in the docker group"
  else
    usermod -aG docker "$target_user" \
      && ok "Added '$target_user' to docker group (log out & back in to take effect)." \
      || warn "Could not add '$target_user' to docker group — do it manually."
  fi
}

export -f install_docker
export -f _docker_add_user
