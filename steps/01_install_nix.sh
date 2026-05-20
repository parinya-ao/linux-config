#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"

if command -v nix >/dev/null 2>&1; then
    log_ok "Nix is already installed: $(nix --version)"
else
    log_step "Installing Nix (Determinate Systems)..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

log_step "Configuring Nix trusted-users..."
NIX_CONF="/etc/nix/nix.conf"
if ! grep -q "trusted-users" "$NIX_CONF" 2>/dev/null; then
  echo "trusted-users = root parinya" >> "$NIX_CONF"
  systemctl restart nix-daemon || true
  log_ok "Added parinya to trusted-users."
fi
