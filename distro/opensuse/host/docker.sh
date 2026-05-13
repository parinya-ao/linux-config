#!/usr/bin/env bash
set -euo pipefail

as_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

echo "==> Installing Docker Engine..."

if ! rpm -q docker >/dev/null 2>&1; then
  as_root zypper --non-interactive in --no-recommends docker docker-compose docker-buildx
fi

as_root systemctl enable --now docker.service

target_user="${SUDO_USER:-}"
if [[ -n "$target_user" ]] && id "$target_user" >/dev/null 2>&1; then
  if groups "$target_user" | grep -qw docker; then
    echo "  * User '$target_user' already in docker group."
  else
    as_root usermod -aG docker "$target_user"
    echo "  * Added '$target_user' to docker group (re-login required)."
  fi
else
  echo "  [INFO] SUDO_USER not set. Add your user manually: sudo usermod -aG docker \$USER"
fi

echo "  [OK] Docker is ready."

