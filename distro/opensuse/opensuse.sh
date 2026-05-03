#!/usr/bin/env bash
# =============================================================================
# 06-drivers-comprehensive-opensuse.sh
# openSUSE (zypper) — Comprehensive Driver, Firmware & Codec Installer
# Supports: openSUSE Leap 15.x / Tumbleweed / Slowroll
# Auto-detects distro type and install state, runs correct phase automatically.
# Usage: sudo bash 06-drivers-comprehensive-opensuse.sh
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

zypper_install() {
  zypper --non-interactive install --no-recommends "$@" \
    && ok "Installed: $*" \
    || warn "Some packages in [$*] unavailable or already present — continuing"
}

zypper_install_rec() {
  # Install with recommends (for meta-packages that need extras)
  zypper --non-interactive install "$@" \
    && ok "Installed (with recommends): $*" \
    || warn "Some packages unavailable — continuing"
}

# ------------------------------------------
# PRE-CHECKS
# ------------------------------------------
[[ $EUID -ne 0 ]] && fail "Must run as root: sudo bash $0"

command -v zypper &>/dev/null || fail "zypper not found. This script is for openSUSE only."

# Confirm openSUSE
if ! grep -qi "opensuse\|suse" /etc/os-release 2>/dev/null; then
  fail "This script targets openSUSE only."
fi

# ------------------------------------------
# DETECT DISTRO TYPE: Tumbleweed or Leap
# ------------------------------------------
DISTRO_ID=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
DISTRO_NAME=$(grep "^NAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
DISTRO_VER=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"' 2>/dev/null || echo "tumbleweed")

IS_TUMBLEWEED=false
IS_LEAP=false

case "${DISTRO_ID}" in
  opensuse-tumbleweed|opensuse-slowroll)
    IS_TUMBLEWEED=true
    PACKMAN_REPO="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/Essentials/"
    PACKMAN_FULL="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/"
    ;;
  opensuse-leap)
    IS_LEAP=true
    PACKMAN_REPO="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${DISTRO_VER}/Essentials/"
    PACKMAN_FULL="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${DISTRO_VER}/"
    ;;
  *)
    warn "Unknown openSUSE variant: ${DISTRO_ID} — assuming Tumbleweed paths."
    IS_TUMBLEWEED=true
    PACKMAN_REPO="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/Essentials/"
    PACKMAN_FULL="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/"
    ;;
esac

info "Detected: ${BOLD}${DISTRO_NAME}${RESET} ${DISTRO_VER}"
info "Tumbleweed mode: ${IS_TUMBLEWEED} | Leap mode: ${IS_LEAP}"

# ------------------------------------------
# AUTO-DETECT STATE
# ------------------------------------------
PACKMAN_ACTIVE=false
FFMPEG_ACTIVE=false
GSTREAMER_UGLY_ACTIVE=false
PPD_ACTIVE=false

zypper repos 2>/dev/null | grep -qi "packman"    && PACKMAN_ACTIVE=true
rpm -q ffmpeg                          &>/dev/null && FFMPEG_ACTIVE=true
rpm -q gstreamer-plugins-ugly          &>/dev/null && GSTREAMER_UGLY_ACTIVE=true
rpm -q power-profiles-daemon           &>/dev/null && PPD_ACTIVE=true

info "State check:"
info "  Packman repo active        : ${PACKMAN_ACTIVE}"
info "  ffmpeg active              : ${FFMPEG_ACTIVE}"
info "  gstreamer-plugins-ugly     : ${GSTREAMER_UGLY_ACTIVE}"
info "  power-profiles-daemon      : ${PPD_ACTIVE}"

# =============================================================================
# PHASE 0 — System refresh (always runs)
# =============================================================================
step "[P0] System refresh..."
zypper --non-interactive refresh
if [[ "${IS_TUMBLEWEED}" == "true" ]]; then
  zypper --non-interactive dist-upgrade --no-recommends \
    && ok "Tumbleweed dup complete." \
    || warn "dup had issues — continuing anyway"
else
  zypper --non-interactive update --no-recommends \
    && ok "Leap update complete." \
    || warn "update had issues — continuing anyway"
fi

# =============================================================================
# ROUND 1 — Packman not yet active → enable repos
# =============================================================================
if [[ "${PACKMAN_ACTIVE}" == "false" ]]; then

  step "[ROUND 1] Enabling Packman & extra repositories..."

  # Add Packman Essentials repo (priority 90 = higher than default)
  step "[1/4] Adding Packman Essentials..."
  zypper addrepo --cfp 90 --name "packman-essentials" \
    "${PACKMAN_REPO}" packman-essentials \
    || warn "packman-essentials may already exist — continuing"

  # Add full Packman for extras like libdvdcss2
  step "[2/4] Adding Packman Full..."
  zypper addrepo --cfp 90 --name "packman" \
    "${PACKMAN_FULL}" packman \
    || warn "packman-full may already exist — continuing"

  # Accept GPG keys non-interactively
  step "[3/4] Refreshing repos with GPG auto-import..."
  zypper --non-interactive --gpg-auto-import-keys refresh \
    && ok "All repos refreshed and GPG keys imported." \
    || warn "Repo refresh had issues — check manually"

  # Install OPI (Open Build Service Package Installer) as helper
  step "[4/4] Installing opi helper..."
  zypper_install opi
  ok "opi installed. Tip: use 'opi codecs' as a quick alternative."

  echo ""
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo -e "${BOLD}|  ROUND 1 COMPLETE                                |${RESET}"
  echo -e "${BOLD}|  Re-run script: sudo bash $0                     |${RESET}"
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  warn "No reboot required — just re-run the script."
  exit 0

fi

# =============================================================================
# ROUND 2 — Packman active, full install
# =============================================================================
if [[ "${PACKMAN_ACTIVE}" == "true" \
   && ( "${FFMPEG_ACTIVE}" == "false" || "${GSTREAMER_UGLY_ACTIVE}" == "false" ) ]]; then

  step "[ROUND 2] Full driver, firmware & codec installation..."
  ok "Packman repo confirmed active."

  # Upgrade packages that have Packman versions first
  step "[PRE] dist-upgrade from Packman (vendor change for codecs)..."
  zypper --non-interactive dist-upgrade \
    --from packman-essentials \
    --from packman \
    --allow-vendor-change \
    --allow-downgrade \
    && ok "Packman vendor switch complete." \
    || warn "Packman vendor switch had issues — continuing"

  # -----------------------------------------------------------------------
  # PHASE 1 — Base firmware (free)
  # -----------------------------------------------------------------------
  step "[P1] Base firmware (free)..."
  zypper_install \
    kernel-firmware \
    kernel-firmware-intel \
    kernel-firmware-iwlwifi \
    kernel-firmware-realtek \
    kernel-firmware-ath10k \
    kernel-firmware-ath11k \
    kernel-firmware-mediatek \
    ucode-intel \
    ucode-amd \
    fwupd

  ok "Base firmware installed."

  # -----------------------------------------------------------------------
  # PHASE 2 — Non-free firmware (Broadcom, bt, dvb, etc.)
  # -----------------------------------------------------------------------
  step "[P2] Non-free & extra firmware..."
  zypper_install \
    kernel-firmware-sound \
    kernel-firmware-bluetooth \
    kernel-firmware-usb-network \
    || warn "Some firmware packages unavailable — continuing"

  # Broadcom Wi-Fi (if applicable)
  zypper_install \
    broadcom-wl \
    broadcom-wl-kmp-default \
    || warn "Broadcom Wi-Fi not needed or unavailable — skipping"

  ok "Non-free firmware installed."

  # -----------------------------------------------------------------------
  # PHASE 3 — Intel Iris Xe GPU + VA-API
  # -----------------------------------------------------------------------
  step "[P3] Intel Iris Xe GPU / VA-API stack..."
  zypper_install \
    intel-media-driver \
    libva2 \
    libva-utils \
    libva-intel-driver \
    Mesa-dri \
    Mesa-dri-nouveau \
    Mesa-vulkan-drivers \
    libvulkan1 \
    vulkan-tools

  # VA-API for Packman-enhanced Mesa (better codec support)
  zypper --non-interactive install \
    --from packman \
    --allow-vendor-change \
    Mesa Mesa-libEGL1 Mesa-libGL1 Mesa-dri \
    && ok "Packman Mesa (VA-API enhanced) installed." \
    || warn "Packman Mesa install skipped — using base Mesa"

  ok "Intel GPU / VA-API stack installed."

  # -----------------------------------------------------------------------
  # PHASE 4 — Audio: SOF firmware + PipeWire
  # -----------------------------------------------------------------------
  step "[P4] Audio — SOF firmware + PipeWire stack..."

  # SOF (Sound Open Firmware) for Intel audio
  zypper_install \
    sof-firmware \
    alsa-firmware \
    alsa-utils \
    alsa-plugins \
    alsa-plugins-pulse

  # PipeWire full stack
  # Note: zypper_install_rec used for pipewire to pull wireplumber-audio
  zypper_install_rec \
    pipewire \
    pipewire-pulseaudio \
    pipewire-alsa \
    pipewire-jack \
    wireplumber \
    pavucontrol

  # Enable PipeWire per-user (openSUSE uses user-level systemd units)
  # We enable globally via /etc/systemd/user presets
  if id "${SUDO_USER:-}" &>/dev/null; then
    TARGET_USER="${SUDO_USER}"
    step "Enabling PipeWire for user: ${TARGET_USER}..."
    sudo -u "${TARGET_USER}" systemctl --user enable --now \
      pipewire.service \
      pipewire.socket \
      pipewire-pulse.service \
      pipewire-pulse.socket \
      wireplumber.service \
      2>/dev/null && ok "PipeWire enabled for user ${TARGET_USER}." \
      || warn "Could not enable PipeWire user services — enable manually after login."
  else
    warn "SUDO_USER not set — enable PipeWire manually after login:"
    warn "  systemctl --user enable --now pipewire pipewire-pulse wireplumber"
  fi

  ok "PipeWire audio stack installed."

  # -----------------------------------------------------------------------
  # PHASE 5 — Multimedia codecs (FFmpeg + GStreamer via Packman)
  # -----------------------------------------------------------------------
  step "[P5] Multimedia codecs — FFmpeg + GStreamer (Packman)..."

  # Full FFmpeg from Packman
  zypper --non-interactive install \
    --from packman \
    --allow-vendor-change \
    ffmpeg \
    && ok "Full FFmpeg (Packman) installed." \
    || warn "ffmpeg from Packman failed — trying default repo"

  # Fallback: install from default repo
  rpm -q ffmpeg &>/dev/null || zypper_install ffmpeg

  # Full GStreamer stack from Packman
  zypper --non-interactive install \
    --from packman \
    --allow-vendor-change \
    gstreamer-plugins-base \
    gstreamer-plugins-good \
    gstreamer-plugins-bad \
    gstreamer-plugins-ugly \
    gstreamer-plugins-libav \
    gstreamer-plugins-good-extra \
    gstreamer-plugins-bad-orig-addon \
    gstreamer-plugins-ugly-orig-addon \
    libavcodec-full \
    && ok "GStreamer Packman stack installed." \
    || warn "GStreamer Packman install had issues — trying base repos"

  # VA-API GStreamer support
  zypper_install gstreamer-plugins-vaapi \
    || warn "gstreamer-plugins-vaapi unavailable — skipping"

  # DVD CSS decryption (libdvdcss2 from Packman)
  zypper --non-interactive install \
    --from packman \
    libdvdcss2 \
    && ok "libdvdcss2 installed (DVD CSS support)." \
    || warn "libdvdcss2 unavailable — DVD decryption not available"

  # x265 / HEVC / MP3 tools
  zypper_install \
    x265 \
    libx265-199 \
    lame \
    opus-tools \
    flac \
    || warn "Some audio/video codec tools unavailable"

  # VLC with full codec support
  zypper --non-interactive install \
    --from packman \
    --allow-vendor-change \
    vlc \
    vlc-codecs \
    && ok "VLC with Packman codecs installed." \
    || warn "VLC Packman install skipped — try: opi codecs"

  ok "Multimedia codecs installed."

  # -----------------------------------------------------------------------
  # PHASE 6 — Bluetooth
  # -----------------------------------------------------------------------
  step "[P6] Bluetooth stack..."
  zypper_install \
    bluez \
    bluez-firmware \
    bluez-obexd \
    bluez-auto-enable-devices \
    kernel-firmware-bluetooth

  systemctl enable --now bluetooth \
    && ok "bluetooth.service enabled & started." \
    || warn "Failed to enable bluetooth.service"

  ok "Bluetooth stack installed."

  # -----------------------------------------------------------------------
  # PHASE 7 — Power management
  # -----------------------------------------------------------------------
  step "[P7] Power management..."
  zypper_install \
    thermald \
    power-profiles-daemon \
    tlp \
    tlp-rdw \
    || warn "Some power packages unavailable"

  # On openSUSE: prefer power-profiles-daemon (GNOME default)
  # Disable TLP if ppd is present to avoid conflict
  if rpm -q power-profiles-daemon &>/dev/null; then
    systemctl disable --now tlp 2>/dev/null \
      && warn "TLP disabled — using power-profiles-daemon (GNOME/KDE default)" \
      || true
    systemctl enable --now power-profiles-daemon \
      && ok "power-profiles-daemon enabled." \
      || warn "power-profiles-daemon enable failed."
  else
    systemctl enable --now tlp \
      && ok "TLP enabled." \
      || warn "TLP enable failed."
  fi

  systemctl enable --now thermald \
    && ok "thermald enabled." \
    || warn "thermald enable failed."

  ok "Power management configured."

  # -----------------------------------------------------------------------
  # PHASE 8 — LVFS firmware updates
  # -----------------------------------------------------------------------
  step "[P8] LVFS firmware check..."
  fwupdmgr refresh --force \
    && fwupdmgr get-updates \
    && ok "LVFS firmware checked." \
    || warn "No firmware updates or fwupd issue — skipping."

  # -----------------------------------------------------------------------
  # PHASE 9 — Extra hardware support
  # -----------------------------------------------------------------------
  step "[P9] Extra hardware support..."

  # Printer support (CUPS)
  zypper_install \
    cups \
    cups-filters \
    system-config-printer \
    || warn "Some printer packages unavailable"

  systemctl enable --now cups \
    && ok "CUPS printing service enabled." \
    || warn "CUPS enable failed."

  # Scanner support
  zypper_install \
    sane-backends \
    xsane \
    || warn "Scanner packages unavailable"

  # Disk tools
  zypper_install \
    smartmontools \
    nvme-cli \
    hdparm \
    || warn "Some disk tools unavailable"

  # Input devices
  zypper_install \
    xf86-input-libinput \
    || warn "libinput already present"

  ok "Extra hardware support installed."

  # -----------------------------------------------------------------------
  # PHASE 10 — Final upgrade & cleanup
  # -----------------------------------------------------------------------
  step "[P10] Final upgrade & cleanup..."

  if [[ "${IS_TUMBLEWEED}" == "true" ]]; then
    zypper --non-interactive dist-upgrade --no-recommends
  else
    zypper --non-interactive update --no-recommends
  fi

  zypper --non-interactive packages --unneeded \
    | awk -F '|' 'NR>2 {gsub(" ",""); print $3}' \
    | xargs -r zypper --non-interactive remove --clean-deps \
    || warn "Autoremove step skipped or nothing to remove"

  ok "System cleanup done."

  # -----------------------------------------------------------------------
  # SUMMARY
  # -----------------------------------------------------------------------
  echo ""
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo -e "${BOLD}|  ROUND 2 COMPLETE — ALL PACKAGES INSTALLED       |${RESET}"
  echo -e "${BOLD}+---------------------------+----------------------+${RESET}"
  echo -e "| Packman Repo              | Essentials + Full    |"
  echo -e "| Firmware (free)           | kernel-firmware-*    |"
  echo -e "| Firmware (nonfree)        | broadcom-wl, bt, sof |"
  echo -e "| Intel Iris Xe GPU         | intel-media-driver   |"
  echo -e "| VA-API + Mesa             | libva2, Packman Mesa |"
  echo -e "| Mesa Vulkan               | Mesa-vulkan-drivers  |"
  echo -e "| Audio (SOF/HDA)           | sof-firmware, alsa   |"
  echo -e "| PipeWire                  | pipewire, wireplumber|"
  echo -e "| FFmpeg (Packman)          | ffmpeg, libavcodec   |"
  echo -e "| GStreamer (Packman)       | gstreamer-plugins-*  |"
  echo -e "| DVD Support               | libdvdcss2           |"
  echo -e "| VLC                       | vlc + vlc-codecs     |"
  echo -e "| Bluetooth                 | bluez, bluez-firmware|"
  echo -e "| Power                     | thermald, ppd/tlp    |"
  echo -e "| Printer/Scanner           | cups, sane-backends  |"
  echo -e "| Firmware Updates          | fwupd LVFS           |"
  echo -e "${BOLD}+---------------------------+----------------------+${RESET}"
  echo ""
  warn "REBOOT required to load new firmware, Mesa, and kernel modules."
  echo -e "  ${YELLOW}sudo reboot${RESET}"
  exit 0

fi

# =============================================================================
# ROUND 3 — Already fully configured
# =============================================================================
if [[ "${PACKMAN_ACTIVE}" == "true" \
   && "${FFMPEG_ACTIVE}" == "true" \
   && "${GSTREAMER_UGLY_ACTIVE}" == "true" ]]; then

  echo ""
  ok "System is already fully configured!"
  info "Packman       : active [DONE]"
  info "ffmpeg        : active [DONE]"
  info "gstreamer-ugly: active [DONE]"
  echo ""
  info "Verify with:"
  info "  vainfo                   → VA-API hardware decode"
  info "  ffmpeg -version          → Codec support"
  info "  pactl info               → PipeWire / PulseAudio"
  info "  fwupdmgr get-updates     → Pending firmware"
  info "  opi                      → OBS Package Installer"
  echo ""
  zypper search --installed-only \
    | grep -E "ffmpeg|gstreamer|intel-media|pipewire" \
    | awk '{print $3, $5}' \
    | head -25
  exit 0

fi
