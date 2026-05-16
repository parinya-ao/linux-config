#!/usr/bin/env bash
set -euo pipefail
source "${BASH_SOURCE[0]%/*}/../../../lib/ui.sh"
source "${BASH_SOURCE[0]%/*}/../../../lib/privilege.sh"

install_optional() {
  local pkg="$1"
  if ! as_root zypper --non-interactive in --no-recommends "$pkg" >/dev/null 2>&1; then
    warn "Failed to install optional package: $pkg"
  fi
}

run_opi_codecs() {
  local opi_help
  opi_help="$(opi --help 2>&1 || true)"

  if echo "$opi_help" | grep -q -- "--non-interactive"; then
    as_root opi --non-interactive codecs
  elif echo "$opi_help" | grep -qE "(^|[[:space:]])-y([[:space:]]|,|$)"; then
    as_root opi codecs -y
  else
    warn "OPI codec installation failed or unsupported version"
  fi
}

step "Installing drivers and codecs"

for pkg in \
  fwupd \
  ucode-intel \
  ucode-amd \
  intel-media-driver \
  vaapi-intel-driver \
  mesa-va-drivers \
  libvdpau_va_gl1 \
  libva-utils \
  Mesa-demo-x
do
  install_optional "$pkg"
done

if lspci -nn 2>/dev/null | grep -qi "10de:"; then
  for pkg in nvidia-driver-G06 nvidia-compute-utils nvidia-kmp-default; do
    install_optional "$pkg"
  done
fi

if ! command -v opi >/dev/null 2>&1; then
  install_optional opi
fi

if command -v opi >/dev/null 2>&1; then
  run_opi_codecs
fi

[[ -d /etc/X11/xorg.conf.d ]] || as_root mkdir -p /etc/X11/xorg.conf.d

if systemctl list-unit-files | grep -q "^NetworkManager.service"; then
  as_root systemctl enable --now NetworkManager.service >/dev/null 2>&1 || true
fi

if systemctl list-unit-files | grep -q "^bluetooth.service"; then
  as_root systemctl enable --now bluetooth.service >/dev/null 2>&1 || true
fi

ok "Drivers and codecs configured"
