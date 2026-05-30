#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2162
# =============================================================================
# fedora.sh - Fedora (dnf) Driver for OS Setup
# Auto-detects install state and runs the correct round automatically.
# Usage: sudo bash fedora.sh   (or bash fedora.sh; sudo will be used as needed)
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

# other package
# shellcheck disable=SC1091
source "$(dirname "$0")/package/ghostty.sh"

# ------------------------------------------
# HELPERS
# ------------------------------------------
step()  { echo -e "\n${BLUE}[STEP]${RESET} $*"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
fail()  { echo -e "${RED}[FAIL]${RESET} $*"; exit 1; }
info()  { echo -e "${YELLOW}[INFO]${RESET} $*"; }

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
  local device_id
  device_id=$(lspci -nn 2>/dev/null | grep -i "10de:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[10de:\K[0-9a-f]{4}' || echo "")

  if [[ -z "$device_id" ]]; then
    return 1
  fi

  # Convert hex to decimal for range comparison
  local device_dec
  device_dec=$((16#$device_id))

  # GPU Series mapping by Device ID ranges
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

# Intel GPU Generation Detection (by Device ID)
detect_intel_generation() {
  # Extract Intel Device ID: [8086:XXXX]
  local device_id
  device_id=$(lspci -nn 2>/dev/null | grep -i "8086:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[8086:\K[0-9a-f]{4}' || echo "")

  if [[ -z "$device_id" ]]; then
    return 1
  fi

  local device_dec
  device_dec=$((16#$device_id))

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
  local device_id
  device_id=$(lspci -nn 2>/dev/null | grep -i "1002:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[1002:\K[0-9a-f]{4}' || echo "")

  if [[ -z "$device_id" ]]; then
    return 1
  fi

  local device_dec
  device_dec=$((16#$device_id))

  if (( device_dec >= 0x7300 )); then
    echo "RDNA (RX 5000+) OpenCL capable"
    return 0
  else
    echo "Legacy (GCN/Polaris)"
    return 0
  fi
}

# Wi-Fi Adapter Detection
detect_wifi_driver() {
  local wifi_vendor
  wifi_vendor=$(lspci 2>/dev/null | grep -i "network.*wireless\|wireless.*controller" | head -1)

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

# Main Hardware Detection
detect_nvidia_gpu() {
  # Detect NVIDIA GPU via Vendor ID 10de
  local nvidia_devices
  nvidia_devices=$(lspci -nn 2>/dev/null | grep -i "10de:" | grep -i "vga\|3d\|display" || echo "")
  if [[ -n "$nvidia_devices" ]]; then
    echo "$nvidia_devices"
    return 0
  fi
  return 1
}

detect_intel_gpu() {
  # Detect Intel GPU via Vendor ID 8086
  local intel_devices
  intel_devices=$(lspci -nn 2>/dev/null | grep -i "8086:" | grep -i "vga\|3d\|display" || echo "")
  if [[ -n "$intel_devices" ]]; then
    echo "$intel_devices"
    return 0
  fi
  return 1
}

detect_amd_discrete_gpu() {
  # Detect discrete AMD GPU (non-iGPU)
  local amd_devices
  amd_devices=$(lspci -nn 2>/dev/null | grep -i "1002:" | grep -i "vga\|3d" | grep -v "00:02" || echo "")
  if [[ -n "$amd_devices" ]]; then
    echo "$amd_devices"
    return 0
  fi
  return 1
}

detect_hybrid_graphics() {
  # Detect if system has both NVIDIA and Intel GPUs (hybrid mode like Optimus)
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
# shellcheck disable=SC2034
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
  # shellcheck disable=SC2034
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
  cp /etc/dnf/dnf.conf "/etc/dnf/dnf.conf.backup.$(date +%s)" 2>/dev/null || true

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
    fwupd-plugin-flashrom \
    dbus-x11

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
  # PHASE 3 — Intel Iris Xe GPU + VA-API (Generation-Aware)
  # -----------------------------------------------------------------------
  step "[P3] Intel Media Driver / VA-API..."

  if [[ "${INTEL_DETECTED}" == "true" ]]; then
    if [[ "${INTEL_DRIVER_ACTIVE}" == "true" ]]; then
      skip "Intel Media Driver already installed"
    else
      step "  → $INTEL_GEN (Media Driver: $INTEL_DRIVER)"

      case "${INTEL_DRIVER}" in
        "iHD")
          info "Installing intel-media-driver (iHD) for modern Intel GPUs..."
          dnf_install intel-media-driver libva2 libva-utils libva-intel-driver || warn "iHD install failed"
          ;;
        "i965"|*)
          info "Installing libva-intel-driver (i965) for legacy Intel GPUs..."
          dnf_install libva-intel-driver libva2 libva-utils || warn "i965 install failed"
          ;;
      esac
    fi
  else
    info "No Intel iGPU detected - skipping Intel Media Driver"
  fi

  # Always install generic VA-API + Mesa
  dnf_install libva2 libva-utils mesa-dri-drivers mesa-vulkan-drivers || true

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
  # PHASE 8.7 — Docker Engine (Modular Script)
  # -----------------------------------------------------------------------
  step "[P8.7] Docker Engine (Modular Script)..."
  bash "$(dirname "$0")/package/docker/docker.sh"

  # -----------------------------------------------------------------------
  # PHASE 8.8 — Custom Browsers (Brave Beta & Firefox Dev Edition)
  # -----------------------------------------------------------------------
  step "[P8.8] Custom Browsers (Brave Beta & Firefox Dev Edition)..."

  # 1. Brave Browser Beta
  step "Installing Brave Browser Beta..."
  dnf install -y dnf-plugins-core
  if dnf --version 2>/dev/null | grep -qiE "dnf5|libdnf5"; then
    dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo
  else
    dnf config-manager --add-repo https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo
  fi
  rpm --import https://brave-browser-rpm-beta.s3.brave.com/brave-core-nightly.asc
  dnf_install brave-browser-beta

  # 2. Firefox Developer Edition
  step "Installing Firefox Developer Edition..."
  bash "$(dirname "$0")/package/firefox-dev/firefox-dev.sh"

  # 3. Uninstall Native Firefox
  step "Uninstalling Native Firefox..."
  dnf remove -y firefox
  ok "Native Firefox removed."

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
  echo -e "| Browsers                  | Brave Beta, FF Dev   |"
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
  dnf list installed | grep -E "ffmpeg|gstreamer1|intel-media" | head -20 || true
  exit 0
fi
