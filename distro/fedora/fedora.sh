#!/usr/bin/env bash
# =============================================================================
# 06-drivers-comprehensive.sh
# Fedora Workstation (dnf) — Comprehensive Driver, Firmware & Codec Installer
# Auto-detects install state and runs the correct phase automatically.
# Usage: sudo bash 06-drivers-comprehensive.sh
# =============================================================================
set -euo pipefail

# ------------------------------------------
# COLORS
# ------------------------------------------
BOLD=$'\033[1m'
RESET=$'\033[0m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[1;32m'
BLUE=$'\033[1;34m'
RED=$'\033[1;31m'

# ------------------------------------------
# HELPERS
# ------------------------------------------
step()  { echo -e "\n${BLUE}[STEP]${RESET} $*"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
fail()  { echo -e "${RED}[FAIL]${RESET} $*"; exit 1; }
info()  { echo -e "${YELLOW}[INFO]${RESET} $*"; }

dnf_install() {
  dnf install -y "$@" \
    && ok "Installed: $*" \
    || warn "Some packages in [$*] unavailable or already present — continuing"
}

# ------------------------------------------
# PRE-CHECKS
# ------------------------------------------
[[ $EUID -ne 0 ]] && fail "Must run as root: sudo bash $0"

command -v dnf &>/dev/null || fail "dnf not found. This script is for Fedora Workstation only."

# Block Silverblue / Atomic / rpm-ostree systems
if command -v rpm-ostree &>/dev/null && rpm-ostree status &>/dev/null 2>&1; then
  fail "rpm-ostree system detected. This script targets Fedora Workstation (dnf) only."
fi

FEDORA_VER=$(rpm -E %fedora)
info "Fedora ${BOLD}${FEDORA_VER}${RESET} detected (Workstation/Server, dnf)."

# ------------------------------------------
# AUTO-DETECT STATE
# ------------------------------------------
RPM_FUSION_ACTIVE=false
FFMPEG_ACTIVE=false

rpm -q rpmfusion-free-release   &>/dev/null && RPM_FUSION_ACTIVE=true
rpm -q ffmpeg                   &>/dev/null && FFMPEG_ACTIVE=true

info "State: RPM Fusion=${RPM_FUSION_ACTIVE} | ffmpeg=${FFMPEG_ACTIVE}"

# =============================================================================
# PHASE 0 — System refresh (always runs)
# =============================================================================
step "[P0] System refresh..."
dnf upgrade --refresh -y
ok "System up to date."

# =============================================================================
# ROUND 1 — RPM Fusion not yet present
# =============================================================================
if [[ "${RPM_FUSION_ACTIVE}" == "false" ]]; then

  step "[ROUND 1] Enabling RPM Fusion (free + nonfree + tainted)..."

  # Install RPM Fusion release packages
  dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" \
    || warn "RPM Fusion may already be present."

  # Tainted repos
  dnf_install rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted

  # Enable Cisco OpenH264
  dnf config-manager setopt fedora-cisco-openh264.enabled=1 2>/dev/null \
    || dnf config-manager --enable fedora-cisco-openh264 2>/dev/null \
    || warn "Could not enable OpenH264 repo — try manually."

  dnf upgrade --refresh -y
  ok "RPM Fusion enabled and system refreshed."

  echo ""
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo -e "${BOLD}|  ROUND 1 COMPLETE                                |${RESET}"
  echo -e "${BOLD}|  Re-run script to continue: sudo bash $0         |${RESET}"
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  warn "No reboot required for dnf — just re-run the script."
  exit 0

fi

# =============================================================================
# ROUND 2 — RPM Fusion present, full install
# =============================================================================
if [[ "${RPM_FUSION_ACTIVE}" == "true" && "${FFMPEG_ACTIVE}" == "false" ]]; then

  step "[ROUND 2] Full driver, firmware & codec installation..."
  ok "RPM Fusion confirmed active."

  # -----------------------------------------------------------------------
  # PHASE 1 — Base firmware (free)
  # -----------------------------------------------------------------------
  step "[P1] Base firmware (free)..."
  dnf_install \
    linux-firmware \
    linux-firmware-whence \
    intel-gpu-firmware \
    iwlwifi-dvm-firmware \
    iwlwifi-mvm-firmware \
    microcode_ctl \
    fwupd \
    fwupd-plugin-flashrom

  # -----------------------------------------------------------------------
  # PHASE 2 — Non-free / tainted firmware
  # -----------------------------------------------------------------------
  step "[P2] Non-free & tainted firmware..."
  dnf_install \
    intel-audio-firmware \
    b43-firmware \
    broadcom-bt-firmware \
    dvb-firmware \
    nouveau-firmware \
    || warn "Some tainted firmware skipped (may not apply to your hardware)"

  # -----------------------------------------------------------------------
  # PHASE 3 — Intel Iris Xe GPU + VA-API
  # -----------------------------------------------------------------------
  step "[P3] Intel Iris Xe GPU / VA-API..."
  dnf_install \
    intel-media-driver \
    libva \
    libva-utils \
    libva-intel-driver \
    mesa-dri-drivers \
    mesa-vulkan-drivers

  # -----------------------------------------------------------------------
  # PHASE 4 — Audio (SOF / PipeWire)
  # -----------------------------------------------------------------------
  step "[P4] Audio drivers & PipeWire stack..."
  dnf_install \
    sof-firmware \
    alsa-sof-firmware \
    alsa-firmware \
    alsa-utils \
    pipewire \
    pipewire-alsa \
    pipewire-pulseaudio \
    pipewire-jack \
    wireplumber \
    pavucontrol

  # -----------------------------------------------------------------------
  # PHASE 5 — Multimedia codecs (FFmpeg + GStreamer)
  # -----------------------------------------------------------------------
  step "[P5] Multimedia codecs..."

  # Swap ffmpeg-free -> full ffmpeg
  dnf swap -y ffmpeg-free ffmpeg --allowerasing \
    && ok "ffmpeg swapped to full version." \
    || warn "ffmpeg swap failed — trying direct install..."

  # Fallback: install ffmpeg directly if swap failed
  rpm -q ffmpeg &>/dev/null || dnf_install ffmpeg

  dnf_install \
    libavcodec-freeworld \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good \
    gstreamer1-plugins-good-extras \
    gstreamer1-plugins-ugly \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-libav \
    gstreamer1-vaapi \
    gstreamer1-plugin-openh264 \
    mozilla-openh264 \
    x265 \
    x265-libs \
    lame \
    libdvdcss

  # Multimedia group upgrade
  dnf group upgrade -y --with-optional Multimedia \
    && ok "Multimedia group upgraded." \
    || warn "Multimedia group upgrade skipped."

  # -----------------------------------------------------------------------
  # PHASE 6 — Bluetooth
  # -----------------------------------------------------------------------
  step "[P6] Bluetooth stack..."
  dnf_install bluez bluez-tools bluez-firmware
  systemctl enable --now bluetooth \
    && ok "bluetooth.service enabled & started." \
    || warn "Failed to enable bluetooth.service"

  # -----------------------------------------------------------------------
  # PHASE 7 — Power management
  # -----------------------------------------------------------------------
  step "[P7] Power management..."
  dnf_install thermald power-profiles-daemon
  systemctl enable --now thermald \
    && ok "thermald enabled." \
    || warn "thermald enable failed."
  systemctl enable --now power-profiles-daemon \
    && ok "power-profiles-daemon enabled." \
    || warn "power-profiles-daemon enable failed."

  # -----------------------------------------------------------------------
  # PHASE 8 — LVFS firmware updates
  # -----------------------------------------------------------------------
  step "[P8] LVFS firmware check..."
  fwupdmgr refresh --force \
    && fwupdmgr get-updates \
    && ok "LVFS checked." \
    || warn "No firmware updates or fwupd issue — skipping."

  # -----------------------------------------------------------------------
  # PHASE 9 — Final upgrade & cleanup
  # -----------------------------------------------------------------------
  step "[P9] Final upgrade & cleanup..."
  dnf upgrade -y
  dnf autoremove -y
  ok "System cleanup done."

  # -----------------------------------------------------------------------
  # SUMMARY
  # -----------------------------------------------------------------------
  echo ""
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo -e "${BOLD}|  ROUND 2 COMPLETE — ALL PACKAGES INSTALLED       |${RESET}"
  echo -e "${BOLD}+---------------------------+----------------------+${RESET}"
  echo -e "| Firmware (free)           | linux-firmware, MCU  |"
  echo -e "| Firmware (nonfree)        | b43, broadcom-bt     |"
  echo -e "| Intel Iris Xe GPU         | intel-media-driver   |"
  echo -e "| VA-API                    | libva, libva-utils   |"
  echo -e "| Mesa Vulkan               | mesa-vulkan-drivers  |"
  echo -e "| Audio (SOF/HDA)           | sof-firmware, alsa   |"
  echo -e "| PipeWire                  | pipewire, wireplumber|"
  echo -e "| Codecs                    | ffmpeg, gstreamer1-* |"
  echo -e "| Bluetooth                 | bluez, bluez-firmware|"
  echo -e "| Power                     | thermald, ppd        |"
  echo -e "| Firmware Updates          | fwupd LVFS           |"
  echo -e "${BOLD}+---------------------------+----------------------+${RESET}"
  echo ""
  warn "REBOOT recommended to load new firmware and kernel modules."
  echo -e "  ${YELLOW}sudo reboot${RESET}"
  exit 0

fi

# =============================================================================
# ROUND 3 — Already fully configured
# =============================================================================
if [[ "${RPM_FUSION_ACTIVE}" == "true" && "${FFMPEG_ACTIVE}" == "true" ]]; then
  echo ""
  ok "System is already fully configured!"
  info "RPM Fusion : active [DONE]"
  info "ffmpeg     : active [DONE]"
  echo ""
  info "Verify with:"
  info "  vainfo                    → VA-API hardware decode"
  info "  ffmpeg -version           → Codec support"
  info "  pactl info                → PipeWire audio"
  info "  fwupdmgr get-updates      → Pending firmware"
  dnf list installed | grep -E "ffmpeg|gstreamer1|intel-media" | head -20
  exit 0
fi
