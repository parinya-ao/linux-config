#!/usr/bin/env bash
set -euo pipefail
source "${BASH_SOURCE[0]%/*}/../../../lib/ui.sh"

as_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

set_priority_if_exists() {
  local alias_name="$1"
  local priority="$2"
  if zypper lr | grep -Eq "(^|[[:space:]|])${alias_name}([[:space:]|]|$)"; then
    as_root zypper --non-interactive mr -p "$priority" "$alias_name"
  fi
}

step "Setting up Packman repos and updating system"

. /etc/os-release

set_priority_if_exists repo-oss 90
set_priority_if_exists repo-non-oss 90

if [[ "${ID:-}" == "opensuse-leap" ]]; then
  PACKMAN_URL="http://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${VERSION_ID}/Essentials/"
else
  PACKMAN_URL="http://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/Essentials/"
fi

if ! zypper lr | grep -qiE "(^|[[:space:]|])packman([[:space:]|]|$)"; then
  as_root zypper --non-interactive ar -cfp 80 "$PACKMAN_URL" packman
fi

as_root zypper --non-interactive --gpg-auto-import-keys ref

if [[ "${ID:-}" == "opensuse-leap" ]]; then
  as_root zypper --non-interactive up --no-recommends
else
  as_root zypper --non-interactive dup --no-recommends --allow-vendor-change
fi

ok "Repos configured and system updated"
