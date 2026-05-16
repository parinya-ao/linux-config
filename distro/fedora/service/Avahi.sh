#!/bin/bash
set -euo pipefail

#!/bin/bash
set -euo pipefail

# ------------------------------------------
# UI HELPERS
# ------------------------------------------
source "${BASH_SOURCE[0]%/*}/../../../lib/ui.sh"

[ "$EUID" -eq 0 ] || fail "Must be root"

step "Stopping Avahi services"
systemctl stop avahi-daemon.service avahi-daemon.socket 2>/dev/null || true
systemctl disable avahi-daemon.service avahi-daemon.socket 2>/dev/null || true

step "Masking Avahi services"
systemctl mask avahi-daemon.service avahi-daemon.socket
systemctl stop passim.service 2>/dev/null || true
systemctl disable passim.service 2>/dev/null || true
systemctl mask passim.service 2>/dev/null || true

step "Creating system presets"
mkdir -p /etc/systemd/system-preset
cat > /etc/systemd/system-preset/10-no-avahi.preset << 'EOF'
disable avahi-daemon.service
disable avahi-daemon.socket
disable passim.service
EOF

step "Configuring Avahi daemon"
if [ -f /etc/avahi/avahi-daemon.conf ]; then
  sed -i \
    -e 's/^#*[[:space:]]*use-ipv4=.*/use-ipv4=no/' \
    -e 's/^#*[[:space:]]*use-ipv6=.*/use-ipv6=no/' \
    -e 's/^#*[[:space:]]*disallow-other-stacks=.*/disallow-other-stacks=yes/' \
    /etc/avahi/avahi-daemon.conf
else
  warn "avahi-daemon.conf not found"
fi

step "Verifying Avahi status"
STATUS="$(systemctl is-enabled avahi-daemon.service 2>/dev/null || echo 'unknown')"
if [ "$STATUS" != "masked" ]; then
  warn "Avahi not masked: $STATUS"
fi

ok "Avahi services disabled and masked"
