#!/usr/bin/env bash
# =============================================================================
# lib/hardware.sh
# Universal Hardware Detection Library
# Shared logic for GPU, Wi-Fi, and Firmware detection.
# =============================================================================

[[ -n "${_LIB_HARDWARE_LOADED:-}" ]] && return 0

# ------------------------------------------
# DETECTION CAPABILITY
# ------------------------------------------
HAVE_LSPCI=true
command -v lspci &>/dev/null || HAVE_LSPCI=false

# ------------------------------------------
# FUNCTIONS
# ------------------------------------------

# NVIDIA GPU Series Detection (by Device ID hex)
detect_nvidia_series() {
  [[ "$HAVE_LSPCI" != "true" ]] && return 1
  local device_id=$(lspci -nn 2>/dev/null | grep -i "10de:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[10de:\K[0-9a-f]{4}' || echo "")
  [[ -z "$device_id" ]] && return 1

  local device_dec=$((16#$device_id))
  if (( device_dec >= 0x2200 )); then
    echo "Ada RTX 40xx (0x2200+)"
    echo "latest"
  elif (( device_dec >= 0x1B80 )); then
    echo "Ampere RTX 30xx (0x1B80+)"
    echo "latest"
  elif (( device_dec >= 0x1600 )); then
    echo "Turing RTX 20xx / GTX 16xx (0x1600+)"
    echo "latest"
  elif (( device_dec >= 0x1380 )); then
    echo "Pascal GTX 10xx (0x1380+)"
    echo "latest"
  elif (( device_dec >= 0x0FC0 )); then
    echo "Maxwell GTX 9xx (0x0FC0+)"
    echo "470"
  elif (( device_dec >= 0x0DC0 )); then
    echo "Kepler GTX 7xx (0x0DC0+)"
    echo "390"
  else
    echo "Unknown NVIDIA GPU (ID: 0x$device_id)"
    echo "latest"
  fi
  return 0
}

# Intel GPU Generation Detection
detect_intel_generation() {
  [[ "$HAVE_LSPCI" != "true" ]] && return 1
  local device_id=$(lspci -nn 2>/dev/null | grep -i "8086:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[8086:\K[0-9a-f]{4}' || echo "")
  [[ -z "$device_id" ]] && return 1

  local device_dec=$((16#$device_id))
  if (( device_dec >= 0x7600 && device_dec <= 0x7FFF )); then
    echo "Arrow Lake 15th Gen+ (0x7600+)"
    echo "iHD"
  elif (( device_dec >= 0x7D00 && device_dec <= 0x7DFF )); then
    echo "Raptor Lake 13th Gen (0x7D00+)"
    echo "iHD"
  elif (( device_dec >= 0x4600 && device_dec <= 0x46FF )); then
    echo "Alder Lake 12th Gen (0x4600+)"
    echo "iHD"
  elif (( device_dec >= 0x9A00 && device_dec <= 0x9AFF )); then
    echo "Tiger Lake 11th Gen (0x9A00+)"
    echo "iHD"
  elif (( device_dec >= 0x8A00 && device_dec <= 0x8AFF )); then
    echo "Ice Lake 10th Gen (0x8A00+)"
    echo "iHD"
  elif (( device_dec >= 0x5900 && device_dec <= 0x59FF )); then
    echo "Coffee Lake 9th Gen (0x5900+)"
    echo "iHD"
  elif (( device_dec >= 0x3E00 && device_dec <= 0x3EFF )); then
    echo "Coffee Lake 8th Gen (0x3E00+)"
    echo "iHD"
  elif (( device_dec >= 0x1900 && device_dec <= 0x19FF )); then
    echo "Skylake 6th Gen (0x1900+)"
    echo "i965"
  elif (( device_dec >= 0x1600 && device_dec <= 0x16FF )); then
    echo "Broadwell 5th Gen (0x1600+)"
    echo "i965"
  else
    echo "Unknown Intel GPU (ID: 0x$device_id)"
    echo "iHD"
  fi
  return 0
}

# AMD GPU Detection
detect_amd_gpu() {
  [[ "$HAVE_LSPCI" != "true" ]] && return 1
  local device_id=$(lspci -nn 2>/dev/null | grep -i "1002:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[1002:\K[0-9a-f]{4}' || echo "")
  [[ -z "$device_id" ]] && return 1

  local device_dec=$((16#$device_id))
  if (( device_dec >= 0x7300 )); then
    echo "RDNA (RX 5000+) OpenCL capable"
  else
    echo "Legacy (GCN/Polaris)"
  fi
  return 0
}

detect_nvidia_gpu() {
  [[ "$HAVE_LSPCI" != "true" ]] && return 1
  local nvidia_devices=$(lspci -nn 2>/dev/null | grep -i "10de:" | grep -i "vga\|3d\|display" || echo "")
  [[ -n "$nvidia_devices" ]] && echo "$nvidia_devices" && return 0
  return 1
}

detect_intel_gpu() {
  [[ "$HAVE_LSPCI" != "true" ]] && return 1
  local intel_devices=$(lspci -nn 2>/dev/null | grep -i "8086:" | grep -i "vga\|3d\|display" || echo "")
  [[ -n "$intel_devices" ]] && echo "$intel_devices" && return 0
  return 1
}

detect_amd_discrete_gpu() {
  [[ "$HAVE_LSPCI" != "true" ]] && return 1
  local amd_devices=$(lspci -nn 2>/dev/null | grep -i "1002:" | grep -i "vga\|3d" | grep -v "00:02" || echo "")
  [[ -n "$amd_devices" ]] && echo "$amd_devices" && return 0
  return 1
}

detect_hybrid_graphics() {
  detect_nvidia_gpu >/dev/null 2>&1 && detect_intel_gpu >/dev/null 2>&1
}

detect_secure_boot_status() {
  if [[ -f /sys/firmware/efi/fw_platform_size ]]; then
    if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
      return 0
    fi
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

export _LIB_HARDWARE_LOADED=1
