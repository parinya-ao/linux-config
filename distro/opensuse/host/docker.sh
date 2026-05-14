#!/usr/bin/env bash
set -euo pipefail

step() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 39 --bold "PHASE START"
  else
    echo "PHASE START"
  fi
}

ok() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 82 "PHASE SUCCESS"
  else
    echo "PHASE SUCCESS"
  fi
}

warn() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 227 "ATTENTION REQUIRED"
  else
    echo "ATTENTION REQUIRED"
  fi
}

as_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

step

if ! rpm -q docker >/dev/null 2>&1; then
  as_root zypper --non-interactive in --no-recommends docker docker-compose docker-buildx
fi

as_root systemctl enable --now docker.service

target_user="${SUDO_USER:-}"
if [[ -n "$target_user" ]] && id "$target_user" >/dev/null 2>&1; then
  if ! groups "$target_user" | grep -qw docker; then
    as_root usermod -aG docker "$target_user"
  fi
else
  warn
fi

ok
