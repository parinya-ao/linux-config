#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DIR="$SCRIPT_DIR/host"

if [[ $EUID -ne 0 ]]; then
  if [[ "${STARTUP_ALLOW_NON_ROOT:-}" == "1" ]]; then
    echo "[WARN] STARTUP_ALLOW_NON_ROOT=1 set; bypassing root check for test mode."
  else
    echo "[FAIL] Must run as root: sudo bash $0" >&2
    exit 1
  fi
fi

if ! command -v zypper >/dev/null 2>&1; then
  echo "[FAIL] zypper not found. This script is for openSUSE only." >&2
  exit 1
fi

if ! grep -qiE "opensuse|suse" /etc/os-release 2>/dev/null; then
  echo "[FAIL] This script targets openSUSE only." >&2
  exit 1
fi

echo "==> Starting openSUSE Host Upgrade..."
bash "$HOST_DIR/snapper.sh"
bash "$HOST_DIR/repos.sh"
bash "$HOST_DIR/drivers.sh"
bash "$HOST_DIR/docker.sh"
echo "==> openSUSE Host Upgrade complete."
