#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DIR="$SCRIPT_DIR/host"

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

status_line() {
  local message="$1"
  if command -v gum >/dev/null 2>&1; then
    gum style "$message"
  else
    echo "$message"
  fi
}

if [[ $EUID -ne 0 ]]; then
  if [[ "${STARTUP_ALLOW_NON_ROOT:-}" == "1" ]]; then
    warn
  else
    fail
  fi
fi

if ! command -v zypper >/dev/null 2>&1; then
  fail
fi

if ! grep -qiE "opensuse|suse" /etc/os-release 2>/dev/null; then
  fail
fi

step
status_line "Running opensuse host setup"
bash "$HOST_DIR/snapper.sh"
bash "$HOST_DIR/repos.sh"
bash "$HOST_DIR/drivers.sh"
bash "$HOST_DIR/docker.sh"
ok
