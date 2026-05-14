#!/bin/bash
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

fail() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 196 --bold "CRITICAL ERROR"
  else
    echo "CRITICAL ERROR"
  fi
  exit 1
}

[ "$EUID" -eq 0 ] || fail

step
systemctl stop avahi-daemon.service avahi-daemon.socket 2>/dev/null || true
systemctl disable avahi-daemon.service avahi-daemon.socket 2>/dev/null || true

step
systemctl mask avahi-daemon.service avahi-daemon.socket
systemctl stop passim.service 2>/dev/null || true
systemctl disable passim.service 2>/dev/null || true
systemctl mask passim.service 2>/dev/null || true

step
mkdir -p /etc/systemd/system-preset
cat > /etc/systemd/system-preset/10-no-avahi.preset << 'EOF'
disable avahi-daemon.service
disable avahi-daemon.socket
disable passim.service
EOF

step
if [ -f /etc/avahi/avahi-daemon.conf ]; then
  sed -i \
    -e 's/^#*[[:space:]]*use-ipv4=.*/use-ipv4=no/' \
    -e 's/^#*[[:space:]]*use-ipv6=.*/use-ipv6=no/' \
    -e 's/^#*[[:space:]]*disallow-other-stacks=.*/disallow-other-stacks=yes/' \
    /etc/avahi/avahi-daemon.conf
else
  warn
fi

step
STATUS="$(systemctl is-enabled avahi-daemon.service 2>/dev/null || echo 'unknown')"
if [ "$STATUS" != "masked" ]; then
  warn
fi

ok
