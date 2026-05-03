#!/bin/bash
set -euo pipefail

echo "[INFO] Checking root..."
[ "$EUID" -eq 0 ] || { echo "[FAIL] Run as root: sudo bash $0"; exit 1; }

echo "[STEP] Stopping avahi..."
systemctl stop    avahi-daemon.service avahi-daemon.socket 2>/dev/null || true
systemctl disable avahi-daemon.service avahi-daemon.socket 2>/dev/null || true
echo "[ OK ] Stopped + disabled."

echo "[STEP] Masking avahi + passim..."
systemctl mask avahi-daemon.service avahi-daemon.socket
systemctl stop    passim.service 2>/dev/null || true
systemctl disable passim.service 2>/dev/null || true
systemctl mask    passim.service  2>/dev/null || true
echo "[ OK ] Masked."

echo "[STEP] Writing systemd preset..."
mkdir -p /etc/systemd/system-preset
cat > /etc/systemd/system-preset/10-no-avahi.preset << 'EOF'
disable avahi-daemon.service
disable avahi-daemon.socket
disable passim.service
EOF
echo "[ OK ] Preset written."

echo "[STEP] Patching avahi-daemon.conf..."
if [ -f /etc/avahi/avahi-daemon.conf ]; then
  sed -i \
    -e 's/^#*[[:space:]]*use-ipv4=.*/use-ipv4=no/'   \
    -e 's/^#*[[:space:]]*use-ipv6=.*/use-ipv6=no/'   \
    -e 's/^#*[[:space:]]*disallow-other-stacks=.*/disallow-other-stacks=yes/' \
    /etc/avahi/avahi-daemon.conf
  echo "[ OK ] avahi-daemon.conf patched."
else
  echo "[WARN] /etc/avahi/avahi-daemon.conf not found — skipping."
fi

echo "[STEP] Verifying..."
STATUS="$(systemctl is-enabled avahi-daemon.service 2>/dev/null || echo 'unknown')"
echo "[INFO] avahi-daemon.service = $STATUS"
if [ "$STATUS" = "masked" ]; then
  echo "[ OK ] DONE — avahi is fully blocked."
else
  echo "[WARN] Unexpected state: $STATUS — check: systemctl status avahi-daemon"
fi
