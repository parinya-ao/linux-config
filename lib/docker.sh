[[ -n "${_LIB_DOCKER_LOADED:-}" ]] && return 0

docker_add_user_to_group() {
  local target_user="${SUDO_USER:-${1:-}}"
  if [[ -z "$target_user" ]]; then
    warn "SUDO_USER not set — add yourself to docker group manually"
    return 0
  fi
  if groups "$target_user" | grep -qw docker; then
    info "'$target_user' is already in the docker group"
  else
    usermod -aG docker "$target_user" \
      && ok "Added '$target_user' to docker group (re-login required)" \
      || warn "Could not add '$target_user' to docker group"
  fi
}

docker_enable_service() {
  systemctl enable --now docker.service \
    && ok "docker.service enabled & started" \
    || warn "Failed to enable docker.service"
}

export _LIB_DOCKER_LOADED=1
