#!/usr/bin/env bash
set -euo pipefail

as_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

set_config_value() {
  local key="$1"
  local value="$2"
  local file="/etc/snapper/configs/root"

  if grep -q "^${key}=" "$file"; then
    as_root sed -i "s/^${key}=.*/${key}=\"${value}\"/" "$file"
  else
    printf '%s="%s"\n' "$key" "$value" | as_root tee -a "$file" >/dev/null
  fi
}

echo "==> Configuring Snapper..."

if ! command -v snapper >/dev/null 2>&1; then
  as_root zypper --non-interactive in --no-recommends snapper
fi

if [[ ! -f /etc/snapper/configs/root ]]; then
  as_root snapper -c root create-config /
fi

set_config_value NUMBER_LIMIT 5
set_config_value NUMBER_LIMIT_IMPORTANT 3
set_config_value TIMELINE_LIMIT_HOURLY 0
set_config_value TIMELINE_LIMIT_DAILY 7
set_config_value TIMELINE_LIMIT_MONTHLY 0

if ! as_root snapper -c root list | grep -Fq "Pre-Nix-Setup"; then
  as_root snapper -c root create --description "Pre-Nix-Setup"
fi

as_root systemctl enable --now snapper-timeline.timer snapper-cleanup.timer >/dev/null 2>&1 || true
echo "  [OK] Snapper limits set and baseline snapshot created."

