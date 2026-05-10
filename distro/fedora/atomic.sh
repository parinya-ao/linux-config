#!/usr/bin/env bash
# =============================================================================
# atomic.sh - Fedora Atomic (rpm-ostree) Driver, Firmware & Codec Installer
# Auto-detects install state and runs the correct round automatically.
# Usage: sudo bash atomic.sh   (or bash atomic.sh; sudo will be used as needed)
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
step() { echo -e "\n${BLUE}[STEP]${RESET} $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
fail() { echo -e "${RED}[FAIL]${RESET} $*"; exit 1; }
info() { echo -e "${YELLOW}[INFO]${RESET} $*"; }

SUDO="sudo"
if [[ $EUID -eq 0 ]]; then
  SUDO=""
fi

need_cmd() { command -v "$1" &>/dev/null || fail "Required command not found: $1"; }

pkg_installed() {
  rpm -q "$1" &>/dev/null
}

skip() {
  info "Skipping: $*"
}

roo_install() {
  info "Layering: $*"
  $SUDO rpm-ostree install --idempotent --allow-inactive "$@" \
    && ok "Layered: $*" \
    || warn "Some packages in [$*] unavailable or already present - continuing"
}

do_reboot() {
  echo ""
  echo -e "${YELLOW}>>> REBOOT REQUIRED <<<${RESET}"
  echo -e "    After reboot, run: ${BOLD}bash $0${RESET}"
  echo ""
  if [ -t 0 ]; then
    read -rp "  Reboot now? [Y/n]: " _ans || true
    _ans="${_ans:-y}"
    [[ "${_ans,,}" == "y" ]] && $SUDO systemctl reboot
  else
    warn "Non-interactive shell: skipping reboot prompt."
  fi
  echo "  Run 'systemctl reboot' when ready."
  exit 0
}

# ------------------------------------------
# GPU DETECTION ENGINE
# ------------------------------------------
detect_nvidia_series() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local device_id
  device_id=$(lspci -nn 2>/dev/null | grep -i "10de:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[10de:\K[0-9a-f]{4}' || echo "")

  if [[ -z "$device_id" ]]; then
    return 1
  fi

  local device_dec=$((16#$device_id))

  if (( device_dec >= 0x2200 )); then
    echo "Ada RTX 40xx (0x2200+)"
    echo "latest"
    return 0
  elif (( device_dec >= 0x1B80 )); then
    echo "Ampere RTX 30xx (0x1B80+)"
    echo "latest"
    return 0
  elif (( device_dec >= 0x1600 )); then
    echo "Turing RTX 20xx / GTX 16xx (0x1600+)"
    echo "latest"
    return 0
  elif (( device_dec >= 0x1380 )); then
    echo "Pascal GTX 10xx (0x1380+)"
    echo "latest"
    return 0
  elif (( device_dec >= 0x0FC0 )); then
    echo "Maxwell GTX 9xx (0x0FC0+)"
    echo "470"
    return 0
  elif (( device_dec >= 0x0DC0 )); then
    echo "Kepler GTX 7xx (0x0DC0+)"
    echo "390"
    return 0
  else
    echo "Unknown NVIDIA GPU (ID: 0x$device_id)"
    echo "latest"
    return 0
  fi
}

detect_intel_generation() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local device_id
  device_id=$(lspci -nn 2>/dev/null | grep -i "8086:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[8086:\K[0-9a-f]{4}' || echo "")

  if [[ -z "$device_id" ]]; then
    return 1
  fi

  local device_dec=$((16#$device_id))

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

detect_amd_gpu() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local device_id
  device_id=$(lspci -nn 2>/dev/null | grep -i "1002:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[1002:\K[0-9a-f]{4}' || echo "")

  if [[ -z "$device_id" ]]; then
    return 1
  fi

  local device_dec=$((16#$device_id))

  if (( device_dec >= 0x7300 )); then
    echo "RDNA (RX 5000+)"
    return 0
  else
    echo "Legacy (GCN/Polaris)"
    return 0
  fi
}

detect_wifi_driver() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local wifi_vendor
  wifi_vendor=$(lspci 2>/dev/null | grep -i "network.*wireless\|wireless.*controller" | head -1 || true)

  if echo "$wifi_vendor" | grep -qi "broadcom\|bcm"; then
    echo "broadcom"
  elif echo "$wifi_vendor" | grep -qi "intel"; then
    echo "intel-wifi"
  elif echo "$wifi_vendor" | grep -qi "realtek\|rtl"; then
    echo "realtek"
  elif echo "$wifi_vendor" | grep -qi "atheros\|qualcomm\|qca"; then
    echo "atheros"
  else
    echo "generic"
  fi
}

detect_nvidia_gpu() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local nvidia_devices
  nvidia_devices=$(lspci -nn 2>/dev/null | grep -i "10de:" | grep -i "vga\|3d\|display" || echo "")
  if [[ -n "$nvidia_devices" ]]; then
    echo "$nvidia_devices"
    return 0
  fi
  return 1
}

detect_intel_gpu() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local intel_devices
  intel_devices=$(lspci -nn 2>/dev/null | grep -i "8086:" | grep -i "vga\|3d\|display" || echo "")
  if [[ -n "$intel_devices" ]]; then
    echo "$intel_devices"
    return 0
  fi
  return 1
}

detect_amd_discrete_gpu() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local amd_devices
  amd_devices=$(lspci -nn 2>/dev/null | grep -i "1002:" | grep -i "vga\|3d" | grep -v "00:02" || echo "")
  if [[ -n "$amd_devices" ]]; then
    echo "$amd_devices"
    return 0
  fi
  return 1
}

detect_hybrid_graphics() {
  if detect_nvidia_gpu >/dev/null 2>&1 && detect_intel_gpu >/dev/null 2>&1; then
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
need_cmd rpm-ostree
need_cmd rpm

if ! rpm-ostree status &>/dev/null 2>&1; then
  fail "rpm-ostree status failed. This script targets Fedora Atomic systems only."
fi

if [[ $EUID -ne 0 ]]; then
  need_cmd sudo
fi

FEDORA_VER=$(rpm -E %fedora)
info "Fedora ${BOLD}${FEDORA_VER}${RESET} detected (Atomic/rpm-ostree)."
info "Script: ${BOLD}$0${RESET}"

HAVE_LSPCI=true
if ! command -v lspci &>/dev/null; then
  HAVE_LSPCI=false
  warn "lspci not found - hardware detection limited. Install pciutils and re-run."
fi

# ------------------------------------------
# HARDWARE DETECTION
# ------------------------------------------
step "[INIT] Hardware scan..."

NVIDIA_DETECTED=false
NVIDIA_SERIES=""
NVIDIA_DRIVER_BRANCH="latest"

INTEL_DETECTED=false
INTEL_GEN=""
INTEL_DRIVER=""

AMD_DETECTED=false
AMD_SERIES=""

WIFI_DRIVER="generic"
HYBRID_MODE=false

if [[ "${HAVE_LSPCI}" == "true" ]]; then
  if detect_nvidia_gpu >/dev/null 2>&1; then
    NVIDIA_DETECTED=true
    read NVIDIA_SERIES NVIDIA_DRIVER_BRANCH < <(detect_nvidia_series)
    info "NVIDIA GPU: $NVIDIA_SERIES"
    info "Driver branch: $NVIDIA_DRIVER_BRANCH"
    detect_nvidia_gpu | sed 's/^/    /'
  fi

  if detect_intel_gpu >/dev/null 2>&1; then
    INTEL_DETECTED=true
    read INTEL_GEN INTEL_DRIVER < <(detect_intel_generation)
    info "Intel iGPU: $INTEL_GEN"
    info "Media driver: $INTEL_DRIVER"
    detect_intel_gpu | sed 's/^/    /'
  fi

  if detect_amd_discrete_gpu >/dev/null 2>&1; then
    AMD_DETECTED=true
    AMD_SERIES=$(detect_amd_gpu | head -1)
    info "AMD GPU: $AMD_SERIES"
    detect_amd_discrete_gpu | sed 's/^/    /'
  fi

  if detect_hybrid_graphics; then
    HYBRID_MODE=true
    info "Hybrid graphics detected (NVIDIA + Intel)"
  fi

  WIFI_DRIVER=$(detect_wifi_driver)
  if [[ "$WIFI_DRIVER" != "generic" ]]; then
    info "Wi-Fi adapter: $WIFI_DRIVER"
  fi
else
  warn "Hardware detection disabled (pciutils missing)."
fi

if [[ "${NVIDIA_DETECTED}" == "false" && "${INTEL_DETECTED}" == "false" && "${AMD_DETECTED}" == "false" ]]; then
  warn "No discrete GPU detected - base graphics support only"
fi

# ------------------------------------------
# AUTO-DETECT: Decide Round automatically
# ------------------------------------------
RPM_FUSION_ACTIVE=false
FFMPEG_ACTIVE=false
NOUVEAU_BLACKLISTED=false
NVIDIA_DRIVER_ACTIVE=false

VAINFO_OUTPUT=$(get_vainfo_output)

rpm -q rpmfusion-free-release &>/dev/null && RPM_FUSION_ACTIVE=true
rpm -q ffmpeg &>/dev/null && FFMPEG_ACTIVE=true

if [[ "${NVIDIA_DETECTED}" == "true" ]] && nvidia_smi_ok; then
  NVIDIA_DRIVER_ACTIVE=true
  info "NVIDIA driver active (nvidia-smi OK)"
elif rpm -qa | grep -qE '^akmod-nvidia'; then
  NVIDIA_DRIVER_ACTIVE=true
  info "NVIDIA driver already installed"
fi

if [[ -f /etc/modprobe.d/nvidia-disable-nouveau.conf ]] || [[ -f /etc/modprobe.d/blacklist-nouveau.conf ]]; then
  NOUVEAU_BLACKLISTED=true
  info "Nouveau already blacklisted"
fi

INTEL_DRIVER_ACTIVE=false
if [[ "${INTEL_DETECTED}" == "true" ]] && vainfo_has "iHD"; then
  INTEL_DRIVER_ACTIVE=true
  info "Intel VA-API (iHD) already active"
elif [[ "${INTEL_DETECTED}" == "true" ]] && vainfo_has "i965"; then
  INTEL_DRIVER_ACTIVE=true
  info "Intel VA-API (i965) already active"
elif pkg_installed "intel-media-driver" || pkg_installed "libva-intel-driver"; then
  INTEL_DRIVER_ACTIVE=true
  info "Intel media driver already installed"
fi

AMD_DRIVER_ACTIVE=false
if [[ "${AMD_DETECTED}" == "true" ]] && vainfo_has "radeonsi"; then
  AMD_DRIVER_ACTIVE=true
  info "AMD VA-API (radeonsi) already active"
elif pkg_installed "rocm-core" || pkg_installed "amdgpu-core"; then
  AMD_DRIVER_ACTIVE=true
  info "AMD driver already installed"
fi

info "State: RPM_Fusion=${RPM_FUSION_ACTIVE} | ffmpeg=${FFMPEG_ACTIVE} | NVIDIA=${NVIDIA_DRIVER_ACTIVE}"

# ---------------------------------------------------------------------
# ROUND 1: RPM Fusion not yet present
# ---------------------------------------------------------------------
if [[ "${RPM_FUSION_ACTIVE}" == "false" ]]; then

  step "AUTO: Round 1 detected - Enabling RPM Fusion..."
  rpm-ostree status

  step "[1/2] Adding RPM Fusion free + nonfree..."
  $SUDO rpm-ostree install --idempotent \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" \
    && ok "RPM Fusion release packages staged." \
    || warn "RPM Fusion may already be staged - continuing."

  step "[2/2] Re-pin RPM Fusion to tracking package..."
  $SUDO rpm-ostree update \
    --uninstall rpmfusion-free-release \
    --uninstall rpmfusion-nonfree-release \
    --install rpmfusion-free-release \
    --install rpmfusion-nonfree-release \
    && ok "RPM Fusion pinned to tracking packages." \
    || warn "Re-pin skipped - may already be tracking version."

  step "[+] Enable Cisco OpenH264 repo..."
  [[ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]] \
    && $SUDO sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/fedora-cisco-openh264.repo \
    && ok "OpenH264 repo enabled." \
    || warn "OpenH264 repo not found yet - will appear after reboot."

  echo ""
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo -e "${BOLD}|  ROUND 1 COMPLETE                                |${RESET}"
  echo -e "${BOLD}|  Reboot -> then re-run script for Round 2         |${RESET}"
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  do_reboot

fi

# ---------------------------------------------------------------------
# ROUND 2: RPM Fusion present, but ffmpeg not yet present
# ---------------------------------------------------------------------
if [[ "${RPM_FUSION_ACTIVE}" == "true" && "${FFMPEG_ACTIVE}" == "false" ]]; then

  step "AUTO: Round 2 detected - Installing packages..."
  ok "RPM Fusion confirmed active."

  step "[P0.2] RPM Fusion tainted repos..."
  roo_install rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted

  # -------------------------------------------------------------------
  # PHASE 0.5: NVIDIA Driver (branch-aware)
  # -------------------------------------------------------------------
  if [[ "${NVIDIA_DETECTED}" == "true" ]]; then
    if [[ "${NVIDIA_DRIVER_ACTIVE}" == "true" ]]; then
      skip "NVIDIA driver already installed"
    else
      step "[P0.5] NVIDIA driver - $NVIDIA_SERIES"

      roo_install kernel-devel

      if [[ "${NOUVEAU_BLACKLISTED}" == "false" ]]; then
        info "Blacklisting nouveau driver..."
        echo "blacklist nouveau" | $SUDO tee /etc/modprobe.d/nvidia-disable-nouveau.conf >/dev/null
        echo "options nouveau modeset=0" | $SUDO tee -a /etc/modprobe.d/nvidia-disable-nouveau.conf >/dev/null
      fi

      case "${NVIDIA_DRIVER_BRANCH}" in
        "390")
          roo_install akmod-nvidia-390xx xorg-x11-drv-nvidia-390xx
          ;;
        "470")
          roo_install akmod-nvidia-470xx xorg-x11-drv-nvidia-470xx
          ;;
        "latest"|*)
          roo_install akmod-nvidia xorg-x11-drv-nvidia
          roo_install nvidia-gpu-firmware nvidia-settings nvidia-utils || true
          ;;
      esac

      if [[ "$NVIDIA_SERIES" == *"RTX"* ]] || [[ "$NVIDIA_SERIES" == *"Ada"* ]] || [[ "$NVIDIA_SERIES" == *"Ampere"* ]]; then
        roo_install cuda-toolkit || warn "CUDA unavailable (optional)"
      fi

      if [[ "${HYBRID_MODE}" == "true" ]]; then
        step "[P0.5-HYBRID] Configuring NVIDIA Prime for hybrid graphics..."
        roo_install nvidia-prime || warn "nvidia-prime unavailable"
      fi

      ok "NVIDIA driver staged (akmod)"
      warn "First boot may take 5-10 minutes for kernel module compilation"
    fi
  fi

  # -------------------------------------------------------------------
  # PHASE 0.6: AMD GPU support
  # -------------------------------------------------------------------
  if [[ "${AMD_DETECTED}" == "true" ]]; then
    if [[ "${AMD_DRIVER_ACTIVE}" == "true" ]]; then
      skip "AMD driver already installed"
    else
      step "[P0.6] AMD GPU support - $AMD_SERIES"
      roo_install libdrm-amd || true

      if [[ "$AMD_SERIES" == RDNA* ]]; then
        info "Installing ROCm compute stack for RDNA..."
        roo_install rocm-core rocm-dkms rocm-smi || warn "ROCm may be unavailable"
      fi
    fi
  fi

  # -------------------------------------------------------------------
  # PHASE 1: Base firmware (free)
  # -------------------------------------------------------------------
  step "[P1] Base firmware (free)..."
  roo_install \
    linux-firmware \
    linux-firmware-whence \
    intel-gpu-firmware \
    iwlwifi-dvm-firmware \
    iwlwifi-mvm-firmware \
    microcode_ctl \
    fwupd \
    fwupd-plugin-flashrom

  # -------------------------------------------------------------------
  # PHASE 2: Non-free / tainted firmware
  # -------------------------------------------------------------------
  step "[P2] Non-free and tainted firmware..."
  roo_install \
    intel-audio-firmware \
    b43-firmware \
    broadcom-bt-firmware \
    dvb-firmware \
    nouveau-firmware \
    || warn "Some tainted firmware skipped (may not apply to your hardware)"

  # -------------------------------------------------------------------
  # PHASE 3: Intel Media Driver / VA-API
  # -------------------------------------------------------------------
  step "[P3] Intel Media Driver / VA-API..."

  if [[ "${INTEL_DETECTED}" == "true" ]]; then
    if [[ "${INTEL_DRIVER_ACTIVE}" == "true" ]]; then
      skip "Intel media driver already installed"
    else
      step "  -> $INTEL_GEN (driver: $INTEL_DRIVER)"

      case "${INTEL_DRIVER}" in
        "iHD")
          info "Installing intel-media-driver (iHD)..."
          roo_install intel-media-driver libva2 libva-utils libva-intel-driver || warn "iHD install failed"
          ;;
        "i965"|*)
          info "Installing libva-intel-driver (i965)..."
          roo_install libva-intel-driver libva2 libva-utils || warn "i965 install failed"
          ;;
      esac
    fi
  else
    info "No Intel iGPU detected - skipping Intel media driver"
  fi

  roo_install libva2 libva-utils mesa-dri-drivers mesa-vulkan-drivers || true

  # -------------------------------------------------------------------
  # PHASE 4: Audio (SOF / PipeWire)
  # -------------------------------------------------------------------
  step "[P4] Audio drivers and PipeWire stack..."
  roo_install \
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

  # -------------------------------------------------------------------
  # PHASE 5: Multimedia codecs (FFmpeg + GStreamer)
  # -------------------------------------------------------------------
  step "[P5] Multimedia codecs..."

  OVERRIDE_PKGS=()
  for pkg in fdk-aac-free ffmpeg-free libavcodec-free libavdevice-free \
             libavfilter-free libavformat-free libavutil-free \
             libpostproc-free libswresample-free libswscale-free; do
    rpm -q "$pkg" &>/dev/null && OVERRIDE_PKGS+=("$pkg")
  done

  if [[ ${#OVERRIDE_PKGS[@]} -gt 0 ]]; then
    info "Overriding: ${OVERRIDE_PKGS[*]}"
    $SUDO rpm-ostree override remove "${OVERRIDE_PKGS[@]}" --install ffmpeg \
      && ok "ffmpeg override staged." \
      || warn "ffmpeg override failed - check: rpm-ostree override status"
  else
    warn "No free ffmpeg packages found to override - installing ffmpeg directly..."
    roo_install ffmpeg
  fi

  roo_install \
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

  # -------------------------------------------------------------------
  # PHASE 6: Bluetooth
  # -------------------------------------------------------------------
  step "[P6] Bluetooth stack..."
  roo_install bluez bluez-tools bluez-firmware
  $SUDO systemctl enable --now bluetooth &>/dev/null \
    && ok "bluetooth.service enabled and started." \
    || warn "Failed to enable bluetooth.service"

  # -------------------------------------------------------------------
  # PHASE 7: Power management
  # -------------------------------------------------------------------
  step "[P7] Power management..."
  roo_install thermald power-profiles-daemon
  $SUDO systemctl enable --now thermald &>/dev/null \
    && ok "thermald enabled." \
    || warn "thermald enable failed."
  $SUDO systemctl enable --now power-profiles-daemon &>/dev/null \
    && ok "power-profiles-daemon enabled." \
    || warn "power-profiles-daemon enable failed."

  # -------------------------------------------------------------------
  # PHASE 8: LVFS firmware updates
  # -------------------------------------------------------------------
  step "[P8] LVFS firmware check..."
  fwupdmgr refresh --force \
    && fwupdmgr get-updates \
    && ok "LVFS checked." \
    || warn "No firmware updates or fwupd issue."

  # -------------------------------------------------------------------
  # PHASE 9: Summary
  # -------------------------------------------------------------------
  step "[P9] Final ostree status..."
  rpm-ostree status

  echo ""
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo -e "${BOLD}|  ROUND 2 COMPLETE - ALL PACKAGES STAGED          |${RESET}"
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo -e "|  Firmware   : linux-firmware, intel/broadcom     |"
  echo -e "|  GPU        : intel-media-driver, mesa-vulkan    |"
  echo -e "|  Audio      : sof-firmware, pipewire             |"
  echo -e "|  Codecs     : ffmpeg, gstreamer1-*, x265, lame   |"
  echo -e "|  Bluetooth  : bluez, bluez-firmware              |"
  echo -e "|  Power      : thermald, power-profiles-daemon    |"
  echo -e "|  Firmware   : fwupd LVFS checked                 |"
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo ""
  echo -e "${YELLOW}  ROLLBACK: rpm-ostree rollback${RESET}"
  do_reboot

fi

# ---------------------------------------------------------------------
# ROUND 3: Everything completed
# ---------------------------------------------------------------------
if [[ "${RPM_FUSION_ACTIVE}" == "true" && "${FFMPEG_ACTIVE}" == "true" ]]; then
  echo ""
  ok "System is already fully configured!"
  info "RPM Fusion: active [DONE]"
  info "ffmpeg     : active [DONE]"
  info "Run ${BOLD}vainfo${RESET} to verify VA-API, ${BOLD}ffmpeg -version${RESET} to verify codecs."
  rpm-ostree status
  exit 0
fi
