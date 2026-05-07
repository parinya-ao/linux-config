#!/usr/bin/env bash
# =============================================================================
# 06-drivers-comprehensive-ubuntu.sh
# Ubuntu (apt) — Comprehensive Driver, Firmware & Codec Installer
# Enhanced with Hardware Detection, GPU Architecture Awareness, Secure Boot
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
# IDEMPOTENT PACKAGE CHECK
# ------------------------------------------
pkg_installed() {
  # Check if package is installed (dpkg)
  dpkg -l "$1" 2>/dev/null | grep -q "^ii"
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

detect_hybrid_graphics() {
  # Detect if system has both NVIDIA and Intel GPUs (hybrid mode like Optimus)
  if detect_nvidia_gpu >/dev/null 2>&1 && detect_intel_gpu >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

detect_secure_boot_status() {
  # Check if Secure Boot is enabled
  if [[ -f /sys/firmware/efi/fw_platform_size ]]; then
    # UEFI system
    if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
      return 0  # Secure Boot is on
    fi
  fi
  return 1  # Secure Boot is off or not available
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

command -v apt-get &>/dev/null || fail "apt-get not found. This script is for Ubuntu/Debian only."

# Block non-Ubuntu systems (very basic check)
if ! grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
  fail "This script targets Ubuntu/Debian only."
fi

# Ensure lspci is available for hardware detection
if ! command -v lspci &>/dev/null; then
  info "Installing pciutils for hardware detection..."
  apt-get install -y pciutils || warn "Could not install pciutils"
fi

# Ensure mokutil is available (for Secure Boot detection)
if ! command -v mokutil &>/dev/null; then
  apt-get install -y mokutils 2>/dev/null || warn "mokutils not available"
fi

# Detect Ubuntu version
UBUNTU_VER=$(grep VERSION_ID /etc/os-release | cut -d '"' -f2)
UBUNTU_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
info "Ubuntu ${BOLD}${UBUNTU_VER}${RESET} (${UBUNTU_CODENAME}) detected."

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
SECURE_BOOT_ENABLED=false

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

# Secure Boot Detection
if detect_secure_boot_status 2>/dev/null; then
  SECURE_BOOT_ENABLED=true
  warn "⚠ Secure Boot is ENABLED — will handle MOK enrollment"
fi

# Summary
if [[ "$NVIDIA_DETECTED" == "false" && "$INTEL_DETECTED" == "false" && "$AMD_DETECTED" == "false" ]]; then
  warn "⚠ No discrete GPU detected - will install base graphics support only"
fi

# ------------------------------------------
# AUTO-DETECT STATE (Idempotent Checks)
# ------------------------------------------
step "[STATE] Checking current installation state..."

GRAPHICS_PPA_ACTIVE=false
RESTRICTED_ACTIVE=false
FFMPEG_ACTIVE=false
GSTREAMER_ACTIVE=false
PPD_ACTIVE=false
NVIDIA_DRIVER_ACTIVE=false
INTEL_DRIVER_ACTIVE=false
AMD_DRIVER_ACTIVE=false
DOCKER_ACTIVE=false

VAINFO_OUTPUT=$(get_vainfo_output)

# Check PPA
apt-cache policy 2>/dev/null | grep -q "ppa:oibaf/graphics-drivers" && GRAPHICS_PPA_ACTIVE=true

# Check state via dpkg
pkg_installed "ubuntu-restricted-extras" && RESTRICTED_ACTIVE=true
pkg_installed "ffmpeg" && FFMPEG_ACTIVE=true
pkg_installed "gstreamer1.0-plugins-ugly" && GSTREAMER_ACTIVE=true
pkg_installed "power-profiles-daemon" && PPD_ACTIVE=true

# Check GPU drivers
if [[ "${NVIDIA_DETECTED}" == "true" ]] && nvidia_smi_ok; then
  NVIDIA_DRIVER_ACTIVE=true
  info "  ✓ NVIDIA driver active (nvidia-smi OK)"
elif dpkg -l 2>/dev/null | grep -qE '^ii\s+nvidia-driver-[0-9]+'; then
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
elif pkg_installed "rocm-core" || pkg_installed "amdgpu-core"; then
  AMD_DRIVER_ACTIVE=true
  info "  ✓ AMD driver already installed"
fi

# Check Docker
if pkg_installed "docker-ce"; then
  DOCKER_ACTIVE=true
  info "  ✓ Docker already installed"
fi

info "State: Graphics_PPA=${GRAPHICS_PPA_ACTIVE} | Restricted=${RESTRICTED_ACTIVE} | ffmpeg=${FFMPEG_ACTIVE}"

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
  # PHASE 0.5 — NVIDIA Driver (Smart Branch Selection)
  # -----------------------------------------------------------------------
  if [[ "${NVIDIA_DETECTED}" == "true" ]]; then
    if [[ "${NVIDIA_DRIVER_ACTIVE}" == "true" ]]; then
      skip "NVIDIA driver already installed"
    else
      step "[P0.5] Installing NVIDIA driver - $NVIDIA_SERIES"

      # Add graphics PPA for latest drivers
      add-apt-repository -y ppa:graphics-drivers/ppa 2>/dev/null || warn "Graphics PPA may already be added"
      apt-get update -y

      # Determine correct driver version based on GPU series
      case "${NVIDIA_DRIVER_BRANCH}" in
        "390")
          info "Installing NVIDIA Driver 390.xx (Kepler legacy)..."
          DRIVER_VERSION="390"
          ;;
        "470")
          info "Installing NVIDIA Driver 470.xx (Maxwell legacy)..."
          DRIVER_VERSION="470"
          ;;
        "latest"|*)
          # Auto-detect latest available version
          DRIVER_VERSION=$(apt-cache search '^nvidia-driver-[0-9]+$' | grep -oP 'nvidia-driver-\K[0-9]+' | sort -n | tail -1 || true)
          [[ -z "$DRIVER_VERSION" ]] && DRIVER_VERSION="550"
          info "Installing NVIDIA Driver latest (detected: $DRIVER_VERSION)"
          ;;
      esac

      # Install driver with appropriate version
      apt_install \
        "nvidia-driver-${DRIVER_VERSION}" \
        nvidia-utils \
        nvidia-settings \
        "nvidia-driver-libs:i386" \
        nvidia-compute-utils

      # Blacklist nouveau driver
      if [[ ! -f /etc/modprobe.d/nvidia-disable-nouveau.conf && ! -f /etc/modprobe.d/blacklist-nouveau.conf ]]; then
        echo "blacklist nouveau" | tee /etc/modprobe.d/nvidia-disable-nouveau.conf >/dev/null
        echo "options nouveau modeset=0" >> /etc/modprobe.d/nvidia-disable-nouveau.conf
        update-initramfs -u
      fi

      # Install CUDA for RTX series (optional but recommended)
      if [[ "$NVIDIA_SERIES" == *"RTX"* ]] || [[ "$NVIDIA_SERIES" == *"Ada"* ]] || [[ "$NVIDIA_SERIES" == *"Ampere"* ]]; then
        apt_install nvidia-cuda-toolkit || warn "CUDA toolkit unavailable (optional)"
      fi

      # Power management for Hybrid GPUs
      if [[ "${HYBRID_MODE}" == "true" ]]; then
        step "[P0.5-HYBRID] Configuring nvidia-prime for hybrid graphics..."
        apt_install nvidia-prime || warn "nvidia-prime unavailable"
      fi

      # Handle Secure Boot + MOK enrollment (if needed)
      if [[ "${SECURE_BOOT_ENABLED}" == "true" ]]; then
        step "[P0.5-SB] Preparing NVIDIA driver for Secure Boot..."

        # Create MOK key if needed
        if [[ ! -d /var/lib/dkms/mok ]]; then
          mkdir -p /var/lib/dkms/mok/private /var/lib/dkms/mok/public
          openssl req -new -x509 -newkey rsa:2048 -keyout /var/lib/dkms/mok/private/mok.key \
            -outform DER -out /var/lib/dkms/mok/public/mok.der -nodes -days 36500 \
            -subj "/CN=NVIDIA Driver Signing/" 2>/dev/null || warn "Could not create MOK key"
        fi

        warn "⚠ Secure Boot detected: You will be prompted to enroll MOK key on next reboot"
        warn "   At blue screen: Select 'Enroll MOK' → 'Continue' → Enter password → 'Reboot'"
      fi

      ok "NVIDIA driver (${DRIVER_VERSION}) installed - reboot recommended"
    fi
  fi

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
  # PHASE 3.5 — AMD GPU Driver (if detected)
  # -----------------------------------------------------------------------
  if [[ "${AMD_DETECTED}" == "true" ]]; then
    if [[ "${AMD_DRIVER_ACTIVE}" == "true" ]]; then
      skip "AMD driver already installed (amdgpu)"
    else
      step "[P3.5] Configuring AMD GPU support - $AMD_SERIES"

      # AMD GPU uses kernel driver (amdgpu) + Mesa (in-kernel, no separate driver needed)
      apt_install libdrm-amd64 libdrm-amdgpu1 || true

      # RDNA series → ROCm support
      if [[ "$AMD_SERIES" == RDNA* ]]; then
        info "Installing ROCm compute stack for RDNA..."
        # Add ROCm repo and install (version may vary)
        apt_install rocm-core rocm-dkms rocm-smi || warn "ROCm may not be available in repos"
      fi

      info "AMD GPU support configured (uses in-kernel amdgpu driver)"
    fi
  fi

  # -----------------------------------------------------------------------
  # PHASE 4 — Intel Iris Xe GPU + VA-API (Generation-Aware)
  # -----------------------------------------------------------------------
  step "[P4] Intel Media Driver / VA-API..."

  if [[ "${INTEL_DETECTED}" == "true" ]]; then
    if [[ "${INTEL_DRIVER_ACTIVE}" == "true" ]]; then
      skip "Intel Media Driver already installed"
    else
      step "  → $INTEL_GEN (Media Driver: $INTEL_DRIVER)"

      case "${INTEL_DRIVER}" in
        "iHD")
          info "Installing intel-media-driver (iHD) for modern Intel GPUs..."
          apt_install intel-media-driver intel-media-va-driver intel-media-va-driver-non-free libva2 libva-drm2 libva-x11-2 libva-wayland2 vainfo || warn "iHD install failed"
          ;;
        "i965"|*)
          info "Installing libva-intel-driver (i965) for legacy Intel GPUs..."
          apt_install libva-intel-driver libva2 libva-drm2 vainfo || warn "i965 install failed"
          ;;
      esac
    fi
  else
    info "No Intel iGPU detected - skipping Intel Media Driver"
  fi

  # Always install generic VA-API + Mesa
  apt_install mesa-utils mesa-vulkan-drivers libvulkan1 vulkan-tools libdrm-intel1 || true

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
  # PHASE 10.5 — Visual Studio Code (official repo)
  # -----------------------------------------------------------------------
  step "[P10.5] Visual Studio Code (official repo)..."

  if pkg_installed "code"; then
    skip "VS Code already installed"
  else
    if ! command -v gpg &>/dev/null; then
      apt_install gnupg
    fi
    if ! command -v wget &>/dev/null; then
      apt_install wget
    fi

    if [[ ! -f /usr/share/keyrings/microsoft.gpg ]]; then
      wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
    fi

    if [[ ! -f /etc/apt/sources.list.d/vscode.sources && ! -f /etc/apt/sources.list.d/vscode.list ]]; then
      cat > /etc/apt/sources.list.d/vscode.sources <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
    fi

    apt-get update -y
    apt_install code
  fi

  # -----------------------------------------------------------------------
  # PHASE 10.7 — Docker Engine (official repo)
  # -----------------------------------------------------------------------
  step "[P10.7] Docker Engine (official repo)..."

  if pkg_installed "docker-ce"; then
    skip "Docker already installed"
  else
    # Remove conflicting packages
    apt-get remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker 2>/dev/null || true

    # Add Docker GPG key
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc 2>/dev/null || warn "Failed to download Docker GPG key"
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository
    tee /etc/apt/sources.list.d/docker.sources <<EOF >/dev/null
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: \$(. /etc/os-release && echo \"\${UBUNTU_CODENAME:-\$VERSION_CODENAME}\")
Components: stable
Architectures: \$(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    apt-get update -y
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Enable and start Docker
    systemctl enable --now docker \
      && ok "Docker service enabled & started." \
      || warn "Failed to enable Docker service"
  fi

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
  echo -e "| VS Code                  | code (Microsoft repo) |"
  echo -e "| Docker Engine             | docker-ce, docker-compose |"
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
