#!/usr/bin/env bash
set -euo pipefail
trap 'fail "Error on line $LINENO of ${BASH_SOURCE[0]}"' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DIR="$SCRIPT_DIR/host"

# ------------------------------------------
# UI HELPERS
# ------------------------------------------
source "${BASH_SOURCE[0]%/*}/../../lib/ui.sh"

if [[ $EUID -ne 0 ]]; then
  if [[ "${STARTUP_ALLOW_NON_ROOT:-}" == "1" ]]; then
    warn
  else
    fail "Must run as root"
  fi
fi

if ! command -v zypper >/dev/null 2>&1; then
  fail "zypper not found"
fi

if ! grep -qiE "opensuse|suse" /etc/os-release 2>/dev/null; then
  fail "Not openSUSE"
fi

step "Starting openSUSE host setup"
status_line "Running openSUSE host setup"
bash "$HOST_DIR/snapper.sh"
bash "$HOST_DIR/repos.sh"
bash "$HOST_DIR/drivers.sh"
bash "$HOST_DIR/docker.sh"
ok "openSUSE host setup complete"
