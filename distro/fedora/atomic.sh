#!/usr/bin/env bash
# =============================================================================
# atomic.sh - Fedora Atomic (rpm-ostree) Driver, Firmware & Codec Installer
# Auto-detects install state and runs the correct round automatically.
# Usage: sudo bash atomic.sh   (or bash atomic.sh; sudo will be used as needed)
# =============================================================================
set -euo pipefail
trap 'fail "Error on line $LINENO of ${BASH_SOURCE[0]}"' ERR

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
# LIBRARIES & HELPERS
# ------------------------------------------
source "${BASH_SOURCE[0]%/*}/../../lib/ui.sh"
source "${BASH_SOURCE[0]%/*}/../../lib/hardware.sh"
source "${BASH_SOURCE[0]%/*}/../../lib/fedora-common.sh"

SUDO="sudo"
if [[ $EUID -eq 0 ]]; then
  SUDO=""
fi

PKG_INSTALL_CMD="$SUDO rpm-ostree install --idempotent --allow-inactive"
PKG_OVERRIDE_REMOVE_CMD="$SUDO rpm-ostree override remove"

need_cmd() { command -v "$1" &>/dev/null || fail "Required command not found: $1"; }

roo_install() {
  info "Layering: $*"
  $PKG_INSTALL_CMD "$@" \
    && ok "Layered: $*" \
    || warn "Some packages in [$*] unavailable or already present - continuing"
}

do_reboot() {
  warn "REBOOT REQUIRED TO CONTINUE"
  exit 0
}

# ------------------------------------------
# HARDWARE DETECTION ENGINE
# ------------------------------------------
source "${BASH_SOURCE[0]%/*}/../../lib/hardware.sh"

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

  phase_firmware_free
  phase_firmware_nonfree


  phase_intel_media
  phase_audio
  phase_codecs
  phase_bluetooth
  phase_power
  phase_lvfs

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
