#!/usr/bin/env bash
# =============================================================================
# 06-drivers-comprehensive-ubuntu.sh
# Ubuntu (apt) — Comprehensive Driver, Firmware & Codec Installer
# Supports: Ubuntu 22.04 LTS / 24.04 LTS / 24.10 / 25.04+
# Auto-detects install state and runs correct phase automatically.
# Usage: sudo bash 06-drivers-comprehensive-ubuntu.sh
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

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" \
    && ok "Installed: $*" \
    || warn "Some packages in [$*] unavailable or already present — continuing"
}

# ------------------------------------------
# PRE-CHECKS
# ------------------------------------------
[[ $EUID -ne 0 ]] && fail "Must run as root: sudo bash $0"

command -v apt-get &>/dev/null || fail "apt-get not found. This script is for Ubuntu/Debian only."

# Block non-Ubuntu systems (very basic check)
if ! grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
  fail "This script targets Ubuntu/Debian only."
fi

# Detect Ubuntu version
UBUNTU_VER=$(grep VERSION_ID /etc/os-release | cut -d '"' -f2)
UBUNTU_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
info "Ubuntu ${BOLD}${UBUNTU_VER}${RESET} (${UBUNTU_CODENAME}) detected."

# ------------------------------------------
# AUTO-DETECT STATE
# ------------------------------------------
# State 1: ubuntu-restricted-extras not installed → Round 1
# State 2: restricted-extras present, ffmpeg + gstreamer present → Round 3 (done)
# Otherwise → Round 2

RESTRICTED_ACTIVE=false
FFMPEG_ACTIVE=false
GSTREAMER_ACTIVE=false
PPD_ACTIVE=false

dpkg -l ubuntu-restricted-extras &>/dev/null 2>&1 \
  && [[ $(dpkg -l ubuntu-restricted-extras 2>/dev/null | grep "^ii" | wc -l) -gt 0 ]] \
  && RESTRICTED_ACTIVE=true

dpkg -l ffmpeg &>/dev/null 2>&1 \
  && [[ $(dpkg -l ffmpeg 2>/dev/null | grep "^ii" | wc -l) -gt 0 ]] \
  && FFMPEG_ACTIVE=true

dpkg -l gstreamer1.0-plugins-ugly &>/dev/null 2>&1 \
  && [[ $(dpkg -l gstreamer1.0-plugins-ugly 2>/dev/null | grep "^ii" | wc -l) -gt 0 ]] \
  && GSTREAMER_ACTIVE=true

dpkg -l power-profiles-daemon &>/dev/null 2>&1 \
  && [[ $(dpkg -l power-profiles-daemon 2>/dev/null | grep "^ii" | wc -l) -gt 0 ]] \
  && PPD_ACTIVE=true

info "State check:"
info "  ubuntu-restricted-extras : ${RESTRICTED_ACTIVE}"
info "  ffmpeg                   : ${FFMPEG_ACTIVE}"
info "  gstreamer-ugly           : ${GSTREAMER_ACTIVE}"
info "  power-profiles-daemon    : ${PPD_ACTIVE}"

# =============================================================================
# PHASE 0 — System refresh (always runs first)
# =============================================================================
step "[P0] System refresh..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
ok "System up to date."

# =============================================================================
# ROUND 1 — Enable repositories & base setup (restricted-extras not present)
# =============================================================================
if [[ "${RESTRICTED_ACTIVE}" == "false" ]]; then

  step "[ROUND 1] Enabling repos & installing base packages..."

  # Enable universe, restricted, multiverse repos
  step "[1/4] Adding apt repositories..."
  add-apt-repository -y universe     2>/dev/null || warn "universe may already be enabled"
  add-apt-repository -y restricted   2>/dev/null || warn "restricted may already be enabled"
  add-apt-repository -y multiverse   2>/dev/null || warn "multiverse may already be enabled"
  ok "Ubuntu repos enabled (universe + restricted + multiverse)."

  # Enable contrib/non-free for Debian-based systems
  # For Ubuntu this is handled by 'multiverse' above

  # Add official 'proposed' only if explicitly needed (commented out by default)
  # add-apt-repository -y "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_CODENAME}-proposed main restricted"

  # Refresh package lists after adding repos
  apt-get update -y

  # Install ubuntu-restricted-extras (includes MS fonts, codecs, etc.)
  step "[2/4] Installing ubuntu-restricted-extras..."
  # Accept EULA for ttf-mscorefonts-installer non-interactively
  echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
    | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive apt_install ubuntu-restricted-extras

  # Install software-properties-common for PPA support
  step "[3/4] Installing helper tools..."
  apt_install \
    software-properties-common \
    apt-transport-https \
    curl \
    wget \
    gnupg \
    ca-certificates \
    lsb-release

  # Enable ubuntu-drivers tool
  step "[4/4] Installing ubuntu-drivers-common..."
  apt_install ubuntu-drivers-common
  ok "ubuntu-drivers-common installed."

  echo ""
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo -e "${BOLD}|  ROUND 1 COMPLETE                                |${RESET}"
  echo -e "${BOLD}|  Re-run script: sudo bash $0                     |${RESET}"
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  warn "No reboot required — just re-run the script."
  exit 0

fi

# =============================================================================
# ROUND 2 — Full install (restricted-extras present, ffmpeg/gstreamer not done)
# =============================================================================
if [[ "${RESTRICTED_ACTIVE}" == "true" \
   && ( "${FFMPEG_ACTIVE}" == "false" || "${GSTREAMER_ACTIVE}" == "false" ) ]]; then

  step "[ROUND 2] Full driver, firmware & codec installation..."
  ok "Restricted repos confirmed active."

  # -----------------------------------------------------------------------
  # PHASE 1 — Hardware auto-detection
  # -----------------------------------------------------------------------
  step "[P1] Auto-installing hardware drivers..."

  # ubuntu-drivers autoinstall detects Wi-Fi, GPU, printer drivers etc.
  ubuntu-drivers autoinstall \
    && ok "Hardware drivers auto-installed." \
    || warn "ubuntu-drivers autoinstall failed — check manually: ubuntu-drivers devices"

  # -----------------------------------------------------------------------
  # PHASE 2 — Base firmware (free)
  # -----------------------------------------------------------------------
  step "[P2] Base firmware (free)..."
  apt_install \
    linux-firmware \
    intel-microcode \
    amd64-microcode \
    fwupd \
    fwupd-amd64-signed \
    thermald

  # Intel microcode is CPU brand dependent, ignore if not applicable
  ok "Base firmware installed."

  # -----------------------------------------------------------------------
  # PHASE 3 — Non-free firmware (Broadcom, BCM Wi-Fi, etc.)
  # -----------------------------------------------------------------------
  step "[P3] Non-free firmware & hardware support..."
  apt_install \
    firmware-sof-signed \
    linux-oem-24.04 \
    || warn "Some OEM firmware packages unavailable — continuing"

  # Broadcom Wi-Fi (if present)
  apt_install \
    bcmwl-kernel-source \
    || warn "Broadcom Wi-Fi driver not needed or unavailable — skipping"

  # Realtek / Atheros / generic
  apt_install \
    firmware-linux-free \
    || warn "firmware-linux-free unavailable (Ubuntu uses linux-firmware)"

  ok "Non-free firmware stage done."

  # -----------------------------------------------------------------------
  # PHASE 4 — Intel Iris Xe GPU + VA-API
  # -----------------------------------------------------------------------
  step "[P4] Intel Iris Xe GPU / VA-API..."
  apt_install \
    intel-media-va-driver-non-free \
    intel-media-va-driver \
    libva2 \
    libva-drm2 \
    libva-x11-2 \
    libva-wayland2 \
    vainfo \
    mesa-utils \
    mesa-vulkan-drivers \
    libvulkan1 \
    vulkan-tools \
    libdrm-intel1

  # Intel GPU tools (optional but useful)
  apt_install intel-gpu-tools \
    || warn "intel-gpu-tools unavailable — skipping"

  ok "Intel GPU / VA-API stack installed."

  # -----------------------------------------------------------------------
  # PHASE 5 — Audio: SOF + PipeWire
  # -----------------------------------------------------------------------
  step "[P5] Audio — SOF firmware + PipeWire stack..."

  # SOF (Sound Open Firmware) for modern Intel audio
  apt_install \
    firmware-sof-signed \
    alsa-utils \
    alsa-firmware-loaders \
    || warn "Some SOF packages unavailable"

  # PipeWire full stack (replaces PulseAudio)
  apt_install \
    pipewire \
    pipewire-audio \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    pipewire-audio-client-libraries \
    libspa-0.2-bluetooth \
    libspa-0.2-jack \
    wireplumber \
    pavucontrol \
    gstreamer1.0-pipewire

  # Disable PulseAudio if running — PipeWire replaces it
  systemctl --global disable pulseaudio.service pulseaudio.socket 2>/dev/null \
    || warn "PulseAudio disable skipped (may not be running or user-level)"

  # Enable PipeWire for system
  systemctl --global enable pipewire.service pipewire-pulse.service 2>/dev/null \
    || warn "PipeWire global enable skipped — enable per-user manually if needed"

  ok "PipeWire audio stack installed."

  # -----------------------------------------------------------------------
  # PHASE 6 — Multimedia codecs (FFmpeg + GStreamer)
  # -----------------------------------------------------------------------
  step "[P6] Multimedia codecs — FFmpeg + GStreamer..."

  # Full FFmpeg from Ubuntu repos (includes most codecs)
  apt_install ffmpeg

  # libavcodec-extra adds extra proprietary codecs (AAC, MP3, H.264, etc.)
  apt_install \
    libavcodec-extra \
    libavformat-extra \
    || warn "libavformat-extra unavailable — using standard libavformat"

  # GStreamer full stack
  apt_install \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-vaapi \
    gstreamer1.0-x \
    gstreamer1.0-alsa \
    gstreamer1.0-gl \
    gstreamer1.0-gtk3 \
    gstreamer1.0-pulseaudio

  # libdvd support (CSS decryption for encrypted DVDs)
  apt_install libdvd-pkg \
    && dpkg-reconfigure libdvd-pkg \
    && ok "DVD CSS support configured." \
    || warn "libdvd-pkg unavailable or already configured"

  # H.264 / x265 / HEVC tools
  apt_install \
    x265 \
    x264 \
    libx265-dev \
    libx264-dev \
    || warn "Some codec dev packages unavailable"

  # MP3 / audio encoding
  apt_install \
    lame \
    opus-tools \
    vorbis-tools \
    flac \
    || warn "Some audio codec tools unavailable"

  # OpenH264 (Cisco) for WebRTC / browsers
  apt_install \
    gstreamer1.0-plugins-bad \
    || true  # Already installed above, just ensure it's there

  ok "Multimedia codecs installed."

  # -----------------------------------------------------------------------
  # PHASE 7 — Bluetooth
  # -----------------------------------------------------------------------
  step "[P7] Bluetooth stack..."
  apt_install \
    bluez \
    bluez-tools \
    blueman \
    libldacbt-abr2 \
    libldacbt-enc2 \
    libspa-0.2-bluetooth

  systemctl enable --now bluetooth \
    && ok "bluetooth.service enabled & started." \
    || warn "Failed to enable bluetooth.service"

  ok "Bluetooth stack installed."

  # -----------------------------------------------------------------------
  # PHASE 8 — Power management
  # -----------------------------------------------------------------------
  step "[P8] Power management..."
  apt_install \
    thermald \
    power-profiles-daemon \
    tlp \
    tlp-rdw \
    || warn "Some power packages unavailable"

  # Note: tlp and power-profiles-daemon conflict on some systems
  # Prefer power-profiles-daemon on modern Ubuntu (GNOME default)
  # Disable TLP if ppd is present
  if dpkg -l power-profiles-daemon 2>/dev/null | grep -q "^ii"; then
    systemctl disable --now tlp 2>/dev/null \
      && warn "TLP disabled — using power-profiles-daemon instead (GNOME default)" \
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
  # PHASE 9 — LVFS firmware updates
  # -----------------------------------------------------------------------
  step "[P9] LVFS firmware check..."
  fwupdmgr refresh --force \
    && fwupdmgr get-updates \
    && ok "LVFS firmware checked." \
    || warn "No firmware updates or fwupd issue — skipping."

  # -----------------------------------------------------------------------
  # PHASE 10 — Extra hardware support
  # -----------------------------------------------------------------------
  step "[P10] Extra hardware support..."

  # Touchpad / input devices
  apt_install \
    xserver-xorg-input-libinput \
    || warn "libinput already present"

  # Printer support (CUPS)
  apt_install \
    cups \
    cups-pdf \
    printer-driver-all \
    system-config-printer \
    || warn "Some printer packages unavailable"

  systemctl enable --now cups \
    && ok "CUPS printing service enabled." \
    || warn "CUPS enable failed."

  # Scanner support
  apt_install \
    sane-utils \
    simple-scan \
    || warn "Scanner packages unavailable"

  # Disk tools
  apt_install \
    smartmontools \
    nvme-cli \
    hdparm \
    || warn "Some disk tools unavailable"

  ok "Extra hardware support installed."

  # -----------------------------------------------------------------------
  # PHASE 11 — Final upgrade & cleanup
  # -----------------------------------------------------------------------
  step "[P11] Final upgrade & cleanup..."
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  apt-get autoremove -y
  apt-get autoclean -y
  ok "System cleanup done."

  # -----------------------------------------------------------------------
  # SUMMARY
  # -----------------------------------------------------------------------
  echo ""
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo -e "${BOLD}|  ROUND 2 COMPLETE — ALL PACKAGES INSTALLED       |${RESET}"
  echo -e "${BOLD}+---------------------------+----------------------+${RESET}"
  echo -e "| Hardware Drivers          | ubuntu-drivers auto  |"
  echo -e "| Firmware (free)           | linux-firmware, MCU  |"
  echo -e "| Firmware (nonfree)        | firmware-sof, bcmwl  |"
  echo -e "| Intel Iris Xe GPU         | intel-media-va-driver|"
  echo -e "| VA-API                    | libva2, vainfo       |"
  echo -e "| Mesa Vulkan               | mesa-vulkan-drivers  |"
  echo -e "| Audio (SOF/HDA)           | firmware-sof-signed  |"
  echo -e "| PipeWire                  | pipewire, wireplumber|"
  echo -e "| Codecs                    | ffmpeg, gstreamer1-* |"
  echo -e "| DVD Support               | libdvd-pkg           |"
  echo -e "| Bluetooth                 | bluez, LDAC          |"
  echo -e "| Power                     | thermald, ppd/tlp    |"
  echo -e "| Printer/Scanner           | cups, sane-utils     |"
  echo -e "| Firmware Updates          | fwupd LVFS           |"
  echo -e "${BOLD}+---------------------------+----------------------+${RESET}"
  echo ""
  warn "REBOOT required to load new firmware and kernel modules."
  echo -e "  ${YELLOW}sudo reboot${RESET}"
  exit 0

fi

# =============================================================================
# ROUND 3 — Already fully configured
# =============================================================================
if [[ "${RESTRICTED_ACTIVE}" == "true" \
   && "${FFMPEG_ACTIVE}" == "true" \
   && "${GSTREAMER_ACTIVE}" == "true" ]]; then

  echo ""
  ok "System is already fully configured!"
  info "ubuntu-restricted-extras : active [DONE]"
  info "ffmpeg                   : active [DONE]"
  info "gstreamer-ugly           : active [DONE]"
  echo ""
  info "Verify with:"
  info "  vainfo                   → VA-API hardware decode"
  info "  ffmpeg -version          → Codec support"
  info "  pactl info               → PipeWire audio server"
  info "  fwupdmgr get-updates     → Pending firmware"
  info "  ubuntu-drivers devices   → Available hardware drivers"
  echo ""
  dpkg -l | grep -E "^ii.*(ffmpeg|gstreamer|intel-media|pipewire)" | awk '{print $2, $3}' | head -25
  exit 0

fi
