#!/usr/bin/env bash
set -Eeuo pipefail

# zed-bootstrap.sh
# KISS | modular | cross-distro | native runtime oriented
#
# Supports:
#   Ubuntu / Debian
#   Fedora / RHEL / CentOS Stream
#   openSUSE / SLES
#
# Goals:
#   - install Zed
#   - ensure PATH for bash/zsh/fish
#   - ensure Vulkan runtime basics for native GUI launch
#   - keep script readable and maintainable
#
# Usage:
#   bash zed-bootstrap.sh
#   bash zed-bootstrap.sh --check
#   bash zed-bootstrap.sh --force-settings
#
# Optional:
#   ZED_CHANNEL=preview bash zed-bootstrap.sh
#   ZED_ALLOW_EMULATED_GPU=1 bash zed-bootstrap.sh

# ─────────────────────────────────────────────
# config
# ─────────────────────────────────────────────
ZED_CONFIG_DIR="${HOME}/.config/zed"
ZED_SETTINGS_FILE="${ZED_CONFIG_DIR}/settings.json"
LOCAL_BIN="${HOME}/.local/bin"
ZED_BIN="${LOCAL_BIN}/zed"
ZED_INSTALL_URL="https://zed.dev/install.sh"
ZED_CHANNEL="${ZED_CHANNEL:-stable}"
ZED_ALLOW_EMULATED_GPU="${ZED_ALLOW_EMULATED_GPU:-0}"

FORCE_SETTINGS=0
CHECK_ONLY=0

OS_ID="unknown"
OS_LIKE=""
OS_VER=""
PKG_MGR="unknown"
ARCH="$(uname -m)"
GPU_VENDOR="unknown"

# ─────────────────────────────────────────────
# logging
# ─────────────────────────────────────────────
log()  { printf '[INFO] %s\n' "$*" >&2; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

cmd_exists() { command -v "$1" >/dev/null 2>&1; }

append_line_if_missing() {
  local file="$1" line="$2"
  touch "$file"
  grep -Fqx "$line" "$file" 2>/dev/null || printf '\n%s\n' "$line" >> "$file"
}

# ─────────────────────────────────────────────
# args
# ─────────────────────────────────────────────
parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --check) CHECK_ONLY=1 ;;
      --force-settings) FORCE_SETTINGS=1 ;;
      -h|--help)
        cat <<'EOF'
Usage: bash zed-bootstrap.sh [--check] [--force-settings]

Options:
  --check           Check environment only
  --force-settings  Overwrite existing Zed settings.json

Env:
  ZED_CHANNEL=preview
  ZED_ALLOW_EMULATED_GPU=1
EOF
        exit 0
        ;;
      *)
        warn "Unknown argument: $arg"
        ;;
    esac
  done
}

# ─────────────────────────────────────────────
# os detect
# ─────────────────────────────────────────────
detect_os() {
  [[ -r /etc/os-release ]] || die "/etc/os-release not found"
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_LIKE="${ID_LIKE:-}"
  OS_VER="${VERSION_ID:-}"

  case "$OS_ID" in
    ubuntu|debian|linuxmint|pop|elementary) PKG_MGR="apt" ;;
    fedora|rhel|centos|rocky|almalinux)     PKG_MGR="dnf" ;;
    opensuse*|sles)                         PKG_MGR="zypper" ;;
    *)
      case "$OS_LIKE" in
        *debian*|*ubuntu*) PKG_MGR="apt" ;;
        *fedora*|*rhel*)   PKG_MGR="dnf" ;;
        *suse*)            PKG_MGR="zypper" ;;
      esac
      ;;
  esac
}

# ─────────────────────────────────────────────
# privilege
# ─────────────────────────────────────────────
prepare_sudo() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    warn "Running as root. Zed will install under /root unless HOME is overridden."
    return 0
  fi

  case "$PKG_MGR" in
    apt|dnf|zypper)
      log "This script may install dependencies. Requesting sudo once up front..."
      sudo -v || die "sudo authentication failed"
      ;;
  esac
}

# ─────────────────────────────────────────────
# basics
# ─────────────────────────────────────────────
safety_checks() {
  mkdir -p "$ZED_CONFIG_DIR" "$LOCAL_BIN"
  cmd_exists curl || die "curl is required"

  case "$ARCH" in
    x86_64|aarch64) log "Architecture: $ARCH" ;;
    *) warn "Architecture $ARCH may not be supported by Zed binary releases." ;;
  esac
}

# ─────────────────────────────────────────────
# package helpers
# ─────────────────────────────────────────────
pkg_install() {
  case "$PKG_MGR" in
    apt)
      sudo apt-get update -qq
      sudo apt-get install -y --no-install-recommends "$@"
      ;;
    dnf)
      sudo dnf install -y --setopt=install_weak_deps=False "$@"
      ;;
    zypper)
      sudo zypper install -y --no-recommends "$@"
      ;;
    *)
      die "Unsupported package manager: $PKG_MGR"
      ;;
  esac
}

ensure_detection_tools() {
  case "$PKG_MGR" in
    apt)
      pkg_install pciutils vulkan-tools
      ;;
    dnf)
      pkg_install pciutils vulkan-tools
      ;;
    zypper)
      pkg_install pciutils vulkan-tools
      ;;
    *)
      warn "Cannot auto-install detection tools for $PKG_MGR"
      ;;
  esac
}

# ─────────────────────────────────────────────
# gpu detect
# ─────────────────────────────────────────────
detect_gpu_vendor() {
  GPU_VENDOR="unknown"

  if cmd_exists lspci; then
    local pci
    pci="$(lspci 2>/dev/null | grep -iE 'VGA|3D|Display' || true)"
    case "$pci" in
      *Intel*) GPU_VENDOR="intel" ;;
      *AMD*|*Radeon*) GPU_VENDOR="amd" ;;
      *NVIDIA*|*NVIDIA\ Corporation*) GPU_VENDOR="nvidia" ;;
    esac
  fi

  log "GPU vendor: $GPU_VENDOR"
}

# ─────────────────────────────────────────────
# runtime deps
# ─────────────────────────────────────────────
install_runtime_deps_apt() {
  pkg_install \
    libvulkan1 \
    mesa-vulkan-drivers \
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    libwayland-client0 \
    libx11-6 \
    pciutils \
    vulkan-tools
}

install_runtime_deps_dnf() {
  pkg_install \
    vulkan-loader \
    mesa-vulkan-drivers \
    libxkbcommon \
    libxkbcommon-x11 \
    libwayland-client \
    libX11 \
    mesa-dri-drivers \
    pciutils \
    vulkan-tools
}

install_runtime_deps_zypper() {
  pkg_install \
    libvulkan1 \
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    libwayland-client0 \
    libX11-6 \
    pciutils \
    vulkan-tools

  case "$GPU_VENDOR" in
    intel) pkg_install libvulkan_intel || true ;;
    amd)   pkg_install libvulkan_radeon || true ;;
    nvidia)
      warn "NVIDIA detected on openSUSE. Ensure the proprietary NVIDIA driver repo/package is installed for native Vulkan."
      ;;
    *)
      pkg_install libvulkan_intel libvulkan_radeon || true
      ;;
  esac
}

ensure_runtime_deps() {
  case "$PKG_MGR" in
    apt)    install_runtime_deps_apt ;;
    dnf)    install_runtime_deps_dnf ;;
    zypper) install_runtime_deps_zypper ;;
    *) warn "Unsupported package manager for runtime dependency install: $PKG_MGR" ;;
  esac
}

# ─────────────────────────────────────────────
# vulkan checks
# ─────────────────────────────────────────────
check_vulkan_ready() {
  cmd_exists vulkaninfo || return 1

  local out
  out="$(vulkaninfo 2>&1 || true)"

  if grep -qiE 'NoSupportedDeviceFound|ERROR_INITIALIZATION_FAILED|failed with VK_ERROR' <<<"$out"; then
    return 1
  fi

  if grep -qiE 'llvmpipe|swrast|software rasterizer|lavapipe' <<<"$out"; then
    return 2
  fi

  grep -q 'deviceName' <<<"$out"
}

explain_vulkan_state() {
  local rc="$1"
  case "$rc" in
    0) log "Vulkan: hardware device detected." ;;
    1) warn "Vulkan: no supported native device detected." ;;
    2) warn "Vulkan: only software/emulated renderer detected (llvmpipe/lavapipe)." ;;
    *) warn "Vulkan: unknown status." ;;
  esac
}

ensure_vulkan_native() {
  ensure_detection_tools
  detect_gpu_vendor

  check_vulkan_ready
  local rc=$?
  explain_vulkan_state "$rc"

  if [[ "$rc" -eq 0 ]]; then
    return 0
  fi

  if [[ "$ZED_ALLOW_EMULATED_GPU" = "1" ]]; then
    warn "Emulated GPU explicitly allowed. Skipping native Vulkan enforcement."
    return 0
  fi

  log "Installing native runtime dependencies..."
  ensure_runtime_deps

  check_vulkan_ready
  rc=$?
  explain_vulkan_state "$rc"

  if [[ "$rc" -eq 0 ]]; then
    return 0
  fi

  warn "Still not native-ready after dependency install."
  case "$GPU_VENDOR" in
    nvidia)
      warn "NVIDIA usually needs the proprietary driver stack for working Vulkan on desktop Linux."
      ;;
    amd)
      warn "AMD should normally work with Mesa RADV; check hybrid GPU selection or broken Mesa/ICD setup."
      ;;
    intel)
      warn "Intel should normally work with Mesa ANV; check old hardware generation or missing ICD/runtime files."
      ;;
    *)
      warn "Unknown GPU vendor. Verify host GPU, VM passthrough, and Vulkan ICD installation."
      ;;
  esac
}

# ─────────────────────────────────────────────
# zed install
# ─────────────────────────────────────────────
install_zed() {
  if [[ -x "$ZED_BIN" ]]; then
    log "Zed already installed: $ZED_BIN"
    return 0
  fi

  log "Installing Zed channel=${ZED_CHANNEL}"
  if [[ "$ZED_CHANNEL" = "preview" ]]; then
    curl -fsSL "$ZED_INSTALL_URL" | ZED_CHANNEL=preview sh
  else
    curl -fsSL "$ZED_INSTALL_URL" | sh
  fi

  [[ -x "$ZED_BIN" ]] || die "Zed install finished but binary not found at $ZED_BIN"
}

# ─────────────────────────────────────────────
# settings
# ─────────────────────────────────────────────
write_settings() {
  if [[ -f "$ZED_SETTINGS_FILE" && "$FORCE_SETTINGS" -eq 0 ]]; then
    log "Existing settings.json found. Skipping overwrite."
    return 0
  fi

  mkdir -p "$ZED_CONFIG_DIR"
  cat > "$ZED_SETTINGS_FILE" <<'EOF'
{
  "auto_update": true,
  "format_on_save": "on",
  "theme": "One Dark",
  "auto_install_extensions": {
    "html": true,
    "rust": true,
    "python": true
  }
}
EOF

  log "Wrote settings: $ZED_SETTINGS_FILE"
}

# ─────────────────────────────────────────────
# shell path
# ─────────────────────────────────────────────
setup_bash_path() {
  local export_line='export PATH="$HOME/.local/bin:$PATH"'
  local touched=0

  for rc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile"; do
    if [[ -e "$rc" ]]; then
      append_line_if_missing "$rc" "$export_line"
      touched=1
    fi
  done

  [[ "$touched" -eq 0 ]] && append_line_if_missing "$HOME/.profile" "$export_line"
  export PATH="$HOME/.local/bin:$PATH"
  log "bash-compatible PATH configured."
}

setup_zsh_path() {
  local export_line='export PATH="$HOME/.local/bin:$PATH"'
  if [[ -e "$HOME/.zshrc" ]]; then
    append_line_if_missing "$HOME/.zshrc" "$export_line"
    log "zsh PATH configured."
  else
    warn "~/.zshrc not found; skipping zsh PATH setup."
  fi
}

setup_fish_path() {
  if ! cmd_exists fish; then
    warn "fish not found; skipping fish PATH setup."
    return 0
  fi

  fish -lc 'fish_add_path $HOME/.local/bin' >/dev/null 2>&1 \
    || fish -c 'set -U fish_user_paths $HOME/.local/bin $fish_user_paths' >/dev/null 2>&1 \
    || warn "Could not update fish PATH automatically."

  log "fish PATH configured."
}

# ─────────────────────────────────────────────
# verify
# ─────────────────────────────────────────────
verify_install() {
  export PATH="$HOME/.local/bin:$PATH"

  if cmd_exists zed; then
    log "zed found: $(command -v zed)"
    zed --version >/dev/null 2>&1 || true
    return 0
  fi

  if [[ -x "$ZED_BIN" ]]; then
    warn "zed exists at $ZED_BIN but current shell PATH has not refreshed yet."
    return 0
  fi

  die "zed command not found after installation"
}

run_check() {
  log "OS: ${OS_ID} ${OS_VER}"
  log "PKG_MGR: ${PKG_MGR}"
  log "ARCH: ${ARCH}"
  log "ZED_BIN: $([[ -x "$ZED_BIN" ]] && echo yes || echo no)"
  log "SETTINGS: $([[ -f "$ZED_SETTINGS_FILE" ]] && echo yes || echo no)"

  if cmd_exists vulkaninfo; then
    if vulkaninfo 2>/dev/null | grep -q 'deviceName'; then
      log "Vulkan: present"
    else
      warn "Vulkan: installed but no usable device reported"
    fi
  else
    warn "vulkaninfo: missing"
  fi
}

show_summary() {
  cat <<EOF
Done.

OS:           ${OS_ID} ${OS_VER}
Arch:         ${ARCH}
Pkg mgr:      ${PKG_MGR}
GPU vendor:   ${GPU_VENDOR}
Zed binary:   ${ZED_BIN}
Config file:  ${ZED_SETTINGS_FILE}
Channel:      ${ZED_CHANNEL}

Try:
  zed --version
  zed
EOF
}

# ─────────────────────────────────────────────
# main
# ─────────────────────────────────────────────
main() {
  parse_args "$@"
  detect_os
  prepare_sudo
  safety_checks

  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    ensure_detection_tools
    detect_gpu_vendor
    run_check
    exit 0
  fi

  ensure_vulkan_native
  install_zed
  write_settings
  setup_bash_path
  setup_zsh_path
  setup_fish_path
  verify_install
  show_summary
}

main "$@"
