#!/usr/bin/env bash
[[ -n "${_LIB_PRIVILEGE_LOADED:-}" ]] && return 0

as_root() {
  if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

as_user() {
  if [[ $EUID -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
    local target_user="${SUDO_USER}"
    local target_home
    target_home="$(getent passwd "$target_user" | cut -d: -f6)"
    sudo -u "$target_user" env "HOME=$target_home" "$@"
  else
    "$@"
  fi
}

export _LIB_PRIVILEGE_LOADED=1
