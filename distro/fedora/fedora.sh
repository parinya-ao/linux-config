#!/usr/bin/env bash
# =============================================================================
# 06-drivers-comprehensive.sh
# Fedora Workstation (dnf) — Comprehensive Driver, Firmware & Codec Installer
# Enhanced with Hardware Detection, GPU Architecture Awareness, Secure Boot Handling
# Auto-detects install state and runs the correct phase automatically.
# Usage: sudo bash 06-drivers-comprehensive.sh
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

# other package
source "${BASH_SOURCE[0]%/*}/package/ghostty.sh"

# ------------------------------------------
# LIBRARIES & HELPERS
# ------------------------------------------
source "${BASH_SOURCE[0]%/*}/../../lib/ui.sh"
source "${BASH_SOURCE[0]%/*}/../../lib/docker.sh"
source "${BASH_SOURCE[0]%/*}/../../lib/hardware.sh"
source "${BASH_SOURCE[0]%/*}/../../lib/fedora-common.sh"

PKG_INSTALL_CMD="dnf install -y"
PKG_SWAP_CMD="dnf swap -y"
PKG_GROUP_CMD="dnf group"

dnf_install() {
  $PKG_INSTALL_CMD "$@" \
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

# Ensure lspci is available for hardware detection
if ! command -v lspci &>/dev/null; then
  info "Installing pciutils for hardware detection..."
  dnf install -y pciutils || warn "Could not install pciutils"
fi

FEDORA_VER=$(rpm -E %fedora)
info "Fedora ${BOLD}${FEDORA_VER}${RESET} detected (Workstation/Server, dnf)."

# ------------------------------------------
# HARDWARE DETECTION OUTPUT (Deep Research)
# ------------------------------------------
step "[INIT] Deep hardware research scan..."

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

# NVIDIA Detection
if detect_nvidia_gpu >/dev/null 2>&1; then
  NVIDIA_DETECTED=true
  read NVIDIA_SERIES NVIDIA_DRIVER_BRANCH < <(detect_nvidia_series)
  info "✓ NVIDIA GPU: $NVIDIA_SERIES"
  info "  → Driver branch: $NVIDIA_DRIVER_BRANCH"
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

# Hybrid Detection
if detect_hybrid_graphics; then
  HYBRID_MODE=true
  info "✓ Hybrid Graphics: NVIDIA + Intel Optimus detected"
fi

# Wi-Fi Detection
WIFI_DRIVER=$(detect_wifi_driver)
if [[ "$WIFI_DRIVER" != "generic" ]]; then
  info "✓ Wi-Fi Adapter: $WIFI_DRIVER"
fi

# Summary
if [[ "$NVIDIA_DETECTED" == "false" && "$INTEL_DETECTED" == "false" && "$AMD_DETECTED" == "false" ]]; then
  warn "⚠ No discrete GPU detected - will install base graphics support only"
fi

# ------------------------------------------
# AUTO-DETECT STATE (Idempotent Checks)
# ------------------------------------------
step "[STATE] Checking current installation state..."

RPM_FUSION_ACTIVE=false
FFMPEG_ACTIVE=false
NOUVEAU_BLACKLISTED=false
NVIDIA_DRIVER_ACTIVE=false
DOCKER_ACTIVE=false

VAINFO_OUTPUT=$(get_vainfo_output)

# Check repos
rpm -q rpmfusion-free-release &>/dev/null && RPM_FUSION_ACTIVE=true
rpm -q ffmpeg &>/dev/null && FFMPEG_ACTIVE=true

# Check NVIDIA driver state (any version)
if [[ "${NVIDIA_DETECTED}" == "true" ]] && nvidia_smi_ok; then
  NVIDIA_DRIVER_ACTIVE=true
  info "  ✓ NVIDIA driver active (nvidia-smi OK)"
elif rpm -qa | grep -qE '^akmod-nvidia'; then
  NVIDIA_DRIVER_ACTIVE=true
  info "  ✓ NVIDIA driver already installed"
fi

# Check if nouveau is blacklisted
if [[ -f /etc/modprobe.d/nvidia-disable-nouveau.conf ]] || [[ -f /etc/modprobe.d/blacklist-nouveau.conf ]]; then
  NOUVEAU_BLACKLISTED=true
  info "  ✓ Nouveau already blacklisted"
fi

# Check Intel driver state
INTEL_DRIVER_ACTIVE=false
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

# Check AMD driver state
AMD_DRIVER_ACTIVE=false
if [[ "${AMD_DETECTED}" == "true" ]] && vainfo_has "radeonsi"; then
  AMD_DRIVER_ACTIVE=true
  info "  ✓ AMD VA-API (radeonsi) already active"
elif pkg_installed "rocm-core" || pkg_installed "amdgpu-core"; then
  AMD_DRIVER_ACTIVE=true
  info "  ✓ AMD driver already installed"
fi

# Check Docker
if pkg_installed "docker-ce"; then
  DOCKER_ACTIVE=true
  info "  ✓ Docker already installed"
fi

info "State: RPM_Fusion=${RPM_FUSION_ACTIVE} | ffmpeg=${FFMPEG_ACTIVE} | NVIDIA=${NVIDIA_DRIVER_ACTIVE}"

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
  # PHASE 0.25 — DNF Optimization (Performance Tuning)
  # -----------------------------------------------------------------------
  step "[P0.25] Configuring DNF for optimal performance..."

  # Backup dnf.conf
  cp /etc/dnf/dnf.conf /etc/dnf/dnf.conf.backup.$(date +%s) 2>/dev/null || true

  # Add or update DNF performance settings
  # Check if max_parallel_downloads already exists
  if grep -q "^max_parallel_downloads=" /etc/dnf/dnf.conf; then
    sed -i 's/^max_parallel_downloads=.*/max_parallel_downloads=20/' /etc/dnf/dnf.conf
  else
    echo "max_parallel_downloads=20" >> /etc/dnf/dnf.conf
  fi

  # Add fastestmirror if not present
  if ! grep -q "^fastestmirror=" /etc/dnf/dnf.conf; then
    echo "fastestmirror=True" >> /etc/dnf/dnf.conf
  else
    sed -i 's/^fastestmirror=.*/fastestmirror=True/' /etc/dnf/dnf.conf
  fi

  # Add keepcache if not present (keep downloaded packages)
  if ! grep -q "^keepcache=" /etc/dnf/dnf.conf; then
    echo "keepcache=True" >> /etc/dnf/dnf.conf
  else
    sed -i 's/^keepcache=.*/keepcache=True/' /etc/dnf/dnf.conf
  fi

  ok "DNF optimizations configured:"
  info "  • max_parallel_downloads = 20 (faster parallel downloads)"
  info "  • fastestmirror = True (use fastest mirror)"
  info "  • keepcache = True (keep downloaded packages)"

  # -----------------------------------------------------------------------
  # PHASE 0.5 — NVIDIA Driver (Smart Branch Selection)
  # -----------------------------------------------------------------------
  if [[ "${NVIDIA_DETECTED}" == "true" ]]; then
    if [[ "${NVIDIA_DRIVER_ACTIVE}" == "true" ]]; then
      skip "NVIDIA driver already installed (akmod)"
    else
      step "[P0.5] Installing NVIDIA driver - $NVIDIA_SERIES"

      # Ensure kernel-devel is present
      if ! pkg_installed "kernel-devel"; then
        info "Installing kernel-devel..."
        dnf install -y kernel-devel || warn "kernel-devel install failed"
      fi

      # Blacklist nouveau ONLY if not already done
      if [[ "${NOUVEAU_BLACKLISTED}" == "false" ]]; then
        info "Blacklisting nouveau driver..."
        echo "blacklist nouveau" | tee /etc/modprobe.d/nvidia-disable-nouveau.conf >/dev/null
        echo "options nouveau modeset=0" >> /etc/modprobe.d/nvidia-disable-nouveau.conf
      fi

      # Install appropriate akmod-nvidia branch
      case "${NVIDIA_DRIVER_BRANCH}" in
        "390")
          info "Installing NVIDIA Driver 390.xx (Kepler legacy)..."
          dnf_install akmod-nvidia-390xx nvidia-driver-libs.i686 nvidia-driver-libs-390xx.i686
          ;;
        "470")
          info "Installing NVIDIA Driver 470.xx (Maxwell legacy)..."
          dnf_install akmod-nvidia-470xx nvidia-driver-libs.i686 nvidia-driver-libs-470xx.i686
          ;;
        "latest"|*)
          info "Installing NVIDIA Driver latest (Pascal+)..."
          dnf_install akmod-nvidia nvidia-driver-libs.i686
          ;;
      esac

      # Additional libraries
      dnf_install nvidia-driver-libs nvidia-gpu-firmware nvidia-settings nvidia-utils || true

      # CUDA Toolkit for RTX series (optional but recommended for compute)
      if [[ "$NVIDIA_SERIES" == *"RTX"* ]] || [[ "$NVIDIA_SERIES" == *"Ada"* ]] || [[ "$NVIDIA_SERIES" == *"Ampere"* ]]; then
        dnf_install cuda-toolkit || warn "CUDA unavailable (optional)"
      fi

      # Power management for Hybrid GPUs
      if [[ "${HYBRID_MODE}" == "true" ]]; then
        step "[P0.5-HYBRID] Configuring NVIDIA Prime for hybrid graphics..."
        dnf_install nvidia-prime || warn "nvidia-prime unavailable"
      fi

      ok "NVIDIA driver (akmod) scheduled for compilation on first boot"
      warn "⏱ First boot may take 5-10 minutes for kernel module compilation"
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

      # AMD GPU uses kernel driver (amdgpu) + Mesa (in-kernel, no separate driver needed)
      # Just ensure libdrm-amd is installed for user-space
      dnf_install libdrm-amd || true

      # RDNA series → ROCm support
      if [[ "$AMD_SERIES" == RDNA* ]]; then
        info "Installing ROCm compute stack for RDNA..."
        dnf_install rocm-core rocm-dkms rocm-smi || warn "ROCm may not be available in repos"
      fi

      info "AMD GPU support configured (uses in-kernel amdgpu driver)"
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

  # -----------------------------------------------------------------------
  # PHASE 8.7 — Docker Engine (official repo)
  # -----------------------------------------------------------------------
  step "[P8.7] Docker Engine (official repo)..."

  if pkg_installed "docker-ce"; then
    skip "Docker already installed"
  else
    # Remove conflicting packages
    dnf remove -y docker docker-client docker-client-latest docker-common docker-latest \
      docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux \
      docker-engine 2>/dev/null || true

    # Add Docker repository
    dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null \
      || warn "Failed to add Docker repository"

    # Install Docker packages
    dnf_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Enable and start Docker
    docker_enable_service
    docker_add_user_to_group

    # Fix iptables if needed
    if journalctl -u docker 2>/dev/null | grep -q "failed to find iptables"; then
      info "Fixing iptables configuration..."
      alternatives --set iptables /usr/bin/iptables-nft 2>/dev/null || true
      systemctl restart docker
    fi
  fi

  # -----------------------------------------------------------------------
  # PHASE 9.5 — Avahi Service (disable)
  # -----------------------------------------------------------------------
  step "[P9.5] Disabling Avahi (mDNS)..."
  if systemctl is-active avahi-daemon >/dev/null 2>&1; then
      systemctl disable --now avahi-daemon
      ok "Avahi disabled."
  else
      skip "Avahi already disabled"
  fi

  # -----------------------------------------------------------------------
  # PHASE 9 — Final upgrade & cleanup
  # -----------------------------------------------------------------------
  step "[P9] Final upgrade & cleanup..."
  dnf upgrade -y
  dnf autoremove -y
  ok "System cleanup done."
  install_ghostty

  # -----------------------------------------------------------------------
  # SUMMARY
  # -----------------------------------------------------------------------
  echo ""
  echo -e "${BOLD}+--------------------------------------------------+${RESET}"
  echo -e "${BOLD}|  ROUND 2 COMPLETE — ALL PACKAGES INSTALLED       |${RESET}"
  echo -e "${BOLD}+---------------------------+----------------------+${RESET}"
  echo -e "| DNF Optimization          | max_parallel=20, fast|"
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
  echo -e "| Docker Engine             | docker-ce, docker-compose |"
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
