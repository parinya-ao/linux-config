#!/usr/bin/env bash
# =============================================================================
# 06-drivers-comprehensive-opensuse.sh
# openSUSE (zypper) — Comprehensive Driver, Firmware & Codec Installer
# Enhanced with Hardware Detection, GPU Architecture Awareness, Secure Boot
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
# IDEMPOTENT PACKAGE CHECK
# ------------------------------------------
pkg_installed() {
  # Check if package is installed (rpm)
  rpm -q "$1" &>/dev/null
}

skip() {
  # Skip message
  info "⊘ Skipping: $*"
}

# ------------------------------------------
# GPU DETECTION ENGINE (Deep Research Mode)
# ------------------------------------------

# NVIDIA GPU Series Detection (by Device ID hex)
detect_nvidia_series() {
  # Extract NVIDIA Device ID from lspci output: [10de:XXXX]
  local device_id=$(lspci -nn 2>/dev/null | grep -i "10de:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[10de:\K[0-9a-f]{4}' || echo "")

  if [[ -z "$device_id" ]]; then
    return 1
  fi

  # Convert hex to decimal for range comparison
  local device_dec=$((16#$device_id))

  # GPU Series mapping by Device ID ranges + openSUSE G-Series mapping
  if (( device_dec >= 0x2200 )); then
    echo "Ada RTX 40xx (0x2200+) → G06"
    echo "G06"
    return 0
  elif (( device_dec >= 0x1B80 )); then
    echo "Ampere RTX 30xx (0x1B80+) → G06"
    echo "G06"
    return 0
  elif (( device_dec >= 0x1600 )); then
    echo "Turing RTX 20xx / GTX 16xx (0x1600+) → G06"
    echo "G06"
    return 0
  elif (( device_dec >= 0x1380 )); then
    echo "Pascal GTX 10xx (0x1380+) → G06"
    echo "G06"
    return 0
  elif (( device_dec >= 0x0FC0 )); then
    echo "Maxwell GTX 9xx (0x0FC0+) → G05"
    echo "G05"
    return 0
  elif (( device_dec >= 0x0DC0 )); then
    echo "Kepler GTX 7xx (0x0DC0+) → G04"
    echo "G04"
    return 0
  else
    echo "Unknown NVIDIA GPU (ID: 0x$device_id) → G06 (default)"
    echo "G06"
    return 0
  fi
}

# Intel GPU Generation Detection (by Device ID)
detect_intel_generation() {
  # Extract Intel Device ID: [8086:XXXX]
  local device_id=$(lspci -nn 2>/dev/null | grep -i "8086:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[8086:\K[0-9a-f]{4}' || echo "")

  if [[ -z "$device_id" ]]; then
    return 1
  fi

  local device_dec=$((16#$device_id))

  # Intel GPU generation by Device ID
  if (( device_dec >= 0x7600 && device_dec <= 0x7FFF )); then
    echo "Arrow Lake 15th Gen+ (0x7600+)"
    echo "iHD"
    return 0
  elif (( device_dec >= 0x7D00 && device_dec <= 0x7DFF )); then
    echo "Raptor Lake 13th Gen (0x7D00+)"
    echo "iHD"
    return 0
  elif (( device_dec >= 0x4600 && device_dec <= 0x46FF )); then
    echo "Alder Lake 12th Gen (0x4600+)"
    echo "iHD"
    return 0
  elif (( device_dec >= 0x9A00 && device_dec <= 0x9AFF )); then
    echo "Tiger Lake 11th Gen (0x9A00+)"
    echo "iHD"
    return 0
  elif (( device_dec >= 0x8A00 && device_dec <= 0x8AFF )); then
    echo "Ice Lake 10th Gen (0x8A00+)"
    echo "iHD"
    return 0
  elif (( device_dec >= 0x5900 && device_dec <= 0x59FF )); then
    echo "Coffee Lake 9th Gen (0x5900+)"
    echo "iHD"
    return 0
  elif (( device_dec >= 0x3E00 && device_dec <= 0x3EFF )); then
    echo "Coffee Lake 8th Gen (0x3E00+)"
    echo "iHD"
    return 0
  elif (( device_dec >= 0x1900 && device_dec <= 0x19FF )); then
    echo "Skylake 6th Gen (0x1900+)"
    echo "i965"
    return 0
  elif (( device_dec >= 0x1600 && device_dec <= 0x16FF )); then
    echo "Broadwell 5th Gen (0x1600+)"
    echo "i965"
    return 0
  else
    echo "Unknown Intel GPU (ID: 0x$device_id)"
    echo "iHD"
    return 0
  fi
}

# AMD GPU Detection (RDNA awareness)
detect_amd_gpu() {
  local device_id=$(lspci -nn 2>/dev/null | grep -i "1002:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[1002:\K[0-9a-f]{4}' || echo "")

  if [[ -z "$device_id" ]]; then
    return 1
  fi

  local device_dec=$((16#$device_id))

  if (( device_dec >= 0x7300 )); then
    echo "RDNA (RX 5000+) OpenCL capable"
    return 0
  else
    echo "Legacy (GCN/Polaris)"
    return 0
  fi
}

# Main Hardware Detection
detect_nvidia_gpu() {
  # Detect NVIDIA GPU via Vendor ID 10de
  local nvidia_devices=$(lspci -nn 2>/dev/null | grep -i "10de:" | grep -i "vga\|3d\|display" || echo "")
  if [[ -n "$nvidia_devices" ]]; then
    echo "$nvidia_devices"
    return 0
  fi
  return 1
}

detect_intel_gpu() {
  # Detect Intel GPU via Vendor ID 8086
  local intel_devices=$(lspci -nn 2>/dev/null | grep -i "8086:" | grep -i "vga\|3d\|display" || echo "")
  if [[ -n "$intel_devices" ]]; then
    echo "$intel_devices"
    return 0
  fi
  return 1
}

detect_amd_discrete_gpu() {
  # Detect discrete AMD GPU (non-iGPU)
  local amd_devices=$(lspci -nn 2>/dev/null | grep -i "1002:" | grep -i "vga\|3d" | grep -v "00:02" || echo "")
  if [[ -n "$amd_devices" ]]; then
    echo "$amd_devices"
    return 0
  fi
  return 1
}

nvidia_smi_ok() {
  command -v nvidia-smi &>/dev/null || return 1
  nvidia-smi -L &>/dev/null 2>&1
}

get_vainfo_output() {
  if command -v vainfo &>/dev/null; then
    vainfo 2>/dev/null || true
  fi
  return 0
}

vainfo_has() {
  local pattern="$1"
  [[ -n "${VAINFO_OUTPUT:-}" ]] && echo "$VAINFO_OUTPUT" | grep -qiE "$pattern"
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

# Ensure lspci is available for hardware detection
if ! command -v lspci &>/dev/null; then
  info "Installing pciutils for hardware detection..."
  zypper --non-interactive install --no-recommends pciutils || warn "Could not install pciutils"
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
# HARDWARE DETECTION OUTPUT (Deep Research)
# ------------------------------------------
step "[INIT] Deep hardware research scan..."

NVIDIA_DETECTED=false
NVIDIA_SERIES=""
NVIDIA_GSERIES="G06"

INTEL_DETECTED=false
INTEL_GEN=""
INTEL_DRIVER=""

AMD_DETECTED=false
AMD_SERIES=""

HYBRID_MODE=false

# NVIDIA Detection
if detect_nvidia_gpu >/dev/null 2>&1; then
  NVIDIA_DETECTED=true
  read NVIDIA_SERIES NVIDIA_GSERIES < <(detect_nvidia_series)
  info "✓ NVIDIA GPU: $NVIDIA_SERIES"
  info "  → G-Series: $NVIDIA_GSERIES"
  detect_nvidia_gpu | sed 's/^/    /'
fi

# Intel Detection
if detect_intel_gpu >/dev/null 2>&1; then
  INTEL_DETECTED=true
  read INTEL_GEN INTEL_DRIVER < <(detect_intel_generation)
  info "✓ Intel iGPU: $INTEL_GEN"
  info "  → Media Driver: $INTEL_DRIVER"
  detect_intel_gpu | sed 's/^/    /'
fi

# AMD Discrete GPU Detection
if detect_amd_discrete_gpu >/dev/null 2>&1; then
  AMD_DETECTED=true
  AMD_SERIES=$(detect_amd_gpu | head -1)
  info "✓ AMD GPU: $AMD_SERIES"
  detect_amd_discrete_gpu | sed 's/^/    /'
fi

# Hybrid Detection (checks for both NVIDIA and Intel GPUs)
if detect_nvidia_gpu >/dev/null 2>&1 && detect_intel_gpu >/dev/null 2>&1; then
  HYBRID_MODE=true
  info "✓ Hybrid Graphics: NVIDIA + Intel Optimus detected"
fi

# Summary
if [[ "$NVIDIA_DETECTED" == "false" && "$INTEL_DETECTED" == "false" && "$AMD_DETECTED" == "false" ]]; then
  warn "⚠ No discrete GPU detected - will install base graphics support only"
fi

# ------------------------------------------
# AUTO-DETECT STATE (Idempotent Checks)
# ------------------------------------------
step "[STATE] Checking current installation state..."

PACKMAN_ACTIVE=false
FFMPEG_ACTIVE=false
GSTREAMER_UGLY_ACTIVE=false
PPD_ACTIVE=false
NVIDIA_DRIVER_ACTIVE=false
INTEL_DRIVER_ACTIVE=false
AMD_DRIVER_ACTIVE=false
DOCKER_ACTIVE=false

VAINFO_OUTPUT=$(get_vainfo_output)

# Check repos
zypper repos 2>/dev/null | grep -qi "packman" && PACKMAN_ACTIVE=true

# Check package state via rpm
pkg_installed "ffmpeg" && FFMPEG_ACTIVE=true
pkg_installed "gstreamer-plugins-ugly" && GSTREAMER_UGLY_ACTIVE=true
pkg_installed "power-profiles-daemon" && PPD_ACTIVE=true

# Check GPU drivers
if [[ "${NVIDIA_DETECTED}" == "true" ]] && nvidia_smi_ok; then
  NVIDIA_DRIVER_ACTIVE=true
  info "  ✓ NVIDIA driver active (nvidia-smi OK)"
elif rpm -qa | grep -qE '^nvidia-driver-G0'; then
  NVIDIA_DRIVER_ACTIVE=true
  info "  ✓ NVIDIA driver already installed"
fi

if [[ "${INTEL_DETECTED}" == "true" ]] && vainfo_has "iHD"; then
  INTEL_DRIVER_ACTIVE=true
  info "  ✓ Intel VA-API (iHD) already active"
elif [[ "${INTEL_DETECTED}" == "true" ]] && vainfo_has "i965"; then
  INTEL_DRIVER_ACTIVE=true
  info "  ✓ Intel VA-API (i965) already active"
elif pkg_installed "intel-media-driver" || pkg_installed "libva-intel-driver"; then
  INTEL_DRIVER_ACTIVE=true
  info "  ✓ Intel Media Driver already installed"
fi

if [[ "${AMD_DETECTED}" == "true" ]] && vainfo_has "radeonsi"; then
  AMD_DRIVER_ACTIVE=true
  info "  ✓ AMD VA-API (radeonsi) already active"
elif pkg_installed "rocm-core"; then
  AMD_DRIVER_ACTIVE=true
  info "  ✓ AMD driver already installed"
fi

# Check Docker
if pkg_installed "docker"; then
  DOCKER_ACTIVE=true
  info "  ✓ Docker already installed"
fi

info "State: Packman=${PACKMAN_ACTIVE} | ffmpeg=${FFMPEG_ACTIVE} | NVIDIA=${NVIDIA_DRIVER_ACTIVE}"

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
  zypper addrepo --priority 90 --name "packman-essentials" \
    "${PACKMAN_REPO}" packman-essentials \
    || warn "packman-essentials may already exist — continuing"

  # Add full Packman for extras like libdvdcss2
  step "[2/4] Adding Packman Full..."
  zypper addrepo --priority 90 --name "packman" \
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
  # PHASE 0.5 — NVIDIA Driver (Auto G-Series Selection)
  # -----------------------------------------------------------------------
  if [[ "${NVIDIA_DETECTED}" == "true" ]]; then
    if [[ "${NVIDIA_DRIVER_ACTIVE}" == "true" ]]; then
      skip "NVIDIA driver already installed"
    else
      step "[P0.5] Installing NVIDIA driver - $NVIDIA_SERIES"

      # NVIDIA_GSERIES already detected: G04 (Kepler), G05 (Maxwell), G06 (Pascal+)
      info "Installing NVIDIA G-series: $NVIDIA_GSERIES"

      # Blacklist nouveau ONLY if not already done
      if [[ ! -f /etc/modprobe.d/nvidia-disable-nouveau.conf && ! -f /etc/modprobe.d/blacklist-nouveau.conf ]]; then
        echo "blacklist nouveau" | tee /etc/modprobe.d/nvidia-disable-nouveau.conf >/dev/null
        echo "options nouveau modeset=0" >> /etc/modprobe.d/nvidia-disable-nouveau.conf
      fi

      zypper_install \
        "nvidia-driver-${NVIDIA_GSERIES}" \
        nvidia-driver-libs \
        nvidia-compute-utils \
        || warn "NVIDIA driver installation from Packman may have issues"

      # Build kernel module
      zypper_install nvidia-kmp-default \
        || warn "NVIDIA kernel module build may require manual intervention"

      # Hybrid graphics support
      if [[ "${HYBRID_MODE}" == "true" ]]; then
        step "[P0.5-HYBRID] Configuring NVIDIA hybrid graphics..."
        zypper_install suse-prime || warn "suse-prime unavailable"
      fi

      ok "NVIDIA driver installation queued (will take effect after reboot)."
    fi
  fi

  # -----------------------------------------------------------------------
  # PHASE 0.6 — AMD GPU Driver (if detected)
  # -----------------------------------------------------------------------
  if [[ "${AMD_DETECTED}" == "true" ]]; then
    if [[ "${AMD_DRIVER_ACTIVE}" == "true" ]]; then
      skip "AMD driver already installed (amdgpu)"
    else
      step "[P0.6] Configuring AMD GPU support - $AMD_SERIES"

      # AMD GPU uses kernel driver (amdgpu) + Mesa (in-kernel)
      zypper_install libdrm-amd || true

      # RDNA series → ROCm support
      if [[ "$AMD_SERIES" == RDNA* ]]; then
        info "Installing ROCm compute stack for RDNA..."
        zypper_install rocm-core rocm-dkms rocm-smi || warn "ROCm may not be available in repos"
      fi

      info "AMD GPU support configured (uses in-kernel amdgpu driver)"
    fi
  fi

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
  # PHASE 3 — Intel Iris Xe GPU + VA-API (Generation-Aware)
  # -----------------------------------------------------------------------
  step "[P3] Intel Media Driver / VA-API stack..."

  if [[ "${INTEL_DETECTED}" == "true" ]]; then
    if [[ "${INTEL_DRIVER_ACTIVE}" == "true" ]]; then
      skip "Intel Media Driver already installed"
    else
      step "  → $INTEL_GEN (Media Driver: $INTEL_DRIVER)"

      case "${INTEL_DRIVER}" in
        "iHD")
          info "Installing intel-media-driver (iHD) for modern Intel GPUs..."
          zypper_install intel-media-driver libva2 libva-utils libva-intel-driver || warn "iHD install failed"
          ;;
        "i965"|*)
          info "Installing libva-intel-driver (i965) for legacy Intel GPUs..."
          zypper_install libva-intel-driver libva2 libva-utils || warn "i965 install failed"
          ;;
      esac
    fi
  else
    info "No Intel iGPU detected - skipping Intel Media Driver"
  fi

  # Always install generic VA-API + Mesa
  zypper_install Mesa-dri Mesa-dri-nouveau Mesa-vulkan-drivers libvulkan1 vulkan-tools || true

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
  # PHASE 9 — Extra hardware & apps
  # -----------------------------------------------------------------------
  step "[P9] Extra hardware & apps..."

  # Brave Browser Beta
  if [[ "${BRAVE_ACTIVE}" == "false" ]]; then
    step "Adding Brave Browser Beta repository..."
    zypper addrepo https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo \
      || warn "Brave repo already exists or could not be added"
    zypper --non-interactive --gpg-auto-import-keys refresh
    zypper_install brave-browser-beta
  fi

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

  # terminal
  zypper_install ptyxis || warn "ptyxis already present"

  ok "Extra hardware support installed."

  # -----------------------------------------------------------------------
  # PHASE 9 — Docker Engine (official repo)
  # -----------------------------------------------------------------------
  step "[P9] Docker Engine (official repo)..."

  if pkg_installed "docker"; then
    skip "Docker already installed"
  else
    # Add Docker repository (openSUSE uses community repo or manual)
    info "Adding Docker repository..."
    zypper addrepo https://download.docker.com/linux/opensuse/docker.repo 2>/dev/null \
      || info "Docker repo may already exist or community repo will be used"

    # Refresh and install Docker
    zypper --non-interactive refresh 2>/dev/null || true
    zypper_install docker docker-compose

    # Enable and start Docker
    systemctl enable --now docker \
      && ok "Docker service enabled & started." \
      || warn "Failed to enable Docker service"
  fi

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
  echo -e "| Docker Engine             | docker, docker-compose|"
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
