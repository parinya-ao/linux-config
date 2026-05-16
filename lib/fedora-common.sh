#!/usr/bin/env bash
# =============================================================================
# lib/fedora-common.sh
# Shared logic for Fedora Workstation (dnf) and Fedora Atomic (rpm-ostree)
# =============================================================================

[[ -n "${_LIB_FEDORA_COMMON_LOADED:-}" ]] && return 0

# PKG_INSTALL_CMD must be set by the caller
# PKG_SWAP_CMD (optional for dnf)
# PKG_GROUP_CMD (optional for dnf)
# PKG_OVERRIDE_REMOVE_CMD (optional for atomic)

pkg_installed() {
  rpm -q "$1" &>/dev/null
}

phase_firmware_free() {
  step "[P1] Base firmware (free)..."
  $PKG_INSTALL_CMD \
    linux-firmware \
    linux-firmware-whence \
    intel-gpu-firmware \
    iwlwifi-dvm-firmware \
    iwlwifi-mvm-firmware \
    microcode_ctl \
    fwupd \
    fwupd-plugin-flashrom
}

phase_firmware_nonfree() {
  step "[P2] Non-free & tainted firmware..."
  $PKG_INSTALL_CMD \
    intel-audio-firmware \
    b43-firmware \
    broadcom-bt-firmware \
    dvb-firmware \
    nouveau-firmware \
    || warn "Some tainted firmware skipped (may not apply to your hardware)"
}

phase_intel_media() {
  step "[P3] Intel Media Driver / VA-API..."
  if [[ "${INTEL_DETECTED:-false}" == "true" ]]; then
    step "  → $INTEL_GEN (Media Driver: $INTEL_DRIVER)"
    case "${INTEL_DRIVER}" in
      "iHD")
        info "Installing intel-media-driver (iHD) for modern Intel GPUs..."
        $PKG_INSTALL_CMD intel-media-driver libva2 libva-utils libva-intel-driver || warn "iHD install failed"
        ;;
      "i965"|*)
        info "Installing libva-intel-driver (i965) for legacy Intel GPUs..."
        $PKG_INSTALL_CMD libva-intel-driver libva2 libva-utils || warn "i965 install failed"
        ;;
    esac
  else
    info "No Intel iGPU detected - skipping Intel Media Driver"
  fi
  # Always install generic VA-API + Mesa
  $PKG_INSTALL_CMD libva2 libva-utils mesa-dri-drivers mesa-vulkan-drivers || true
}

phase_audio() {
  step "[P4] Audio drivers & PipeWire stack..."
  $PKG_INSTALL_CMD \
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
}

phase_codecs() {
  step "[P5] Multimedia codecs..."
  
  if [[ -n "${PKG_SWAP_CMD:-}" ]]; then
    $PKG_SWAP_CMD ffmpeg-free ffmpeg --allowerasing \
      && ok "ffmpeg swapped to full version." \
      || warn "ffmpeg swap failed — trying direct install..."
  elif [[ -n "${PKG_OVERRIDE_REMOVE_CMD:-}" ]]; then
     local OVERRIDE_PKGS=()
     for pkg in fdk-aac-free ffmpeg-free libavcodec-free libavdevice-free \
                libavfilter-free libavformat-free libavutil-free \
                libpostproc-free libswresample-free libswscale-free; do
       rpm -q "$pkg" &>/dev/null && OVERRIDE_PKGS+=("$pkg")
     done
     if [[ ${#OVERRIDE_PKGS[@]} -gt 0 ]]; then
       info "Overriding: ${OVERRIDE_PKGS[*]}"
       $PKG_OVERRIDE_REMOVE_CMD "${OVERRIDE_PKGS[@]}" --install ffmpeg \
         && ok "ffmpeg override staged." \
         || warn "ffmpeg override failed"
     else
       pkg_installed ffmpeg || $PKG_INSTALL_CMD ffmpeg
     fi
  else
    pkg_installed ffmpeg || $PKG_INSTALL_CMD ffmpeg
  fi

  $PKG_INSTALL_CMD \
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

  if [[ -n "${PKG_GROUP_CMD:-}" ]]; then
    $PKG_GROUP_CMD upgrade -y --with-optional Multimedia \
      && ok "Multimedia group upgraded." \
      || warn "Multimedia group upgrade skipped."
  fi
}

phase_bluetooth() {
  step "[P6] Bluetooth stack..."
  $PKG_INSTALL_CMD bluez bluez-tools bluez-firmware
  systemctl enable --now bluetooth \
    && ok "bluetooth.service enabled & started." \
    || warn "Failed to enable bluetooth.service"
}

phase_power() {
  step "[P7] Power management..."
  $PKG_INSTALL_CMD thermald power-profiles-daemon
  systemctl enable --now thermald \
    && ok "thermald enabled." \
    || warn "thermald enable failed."
  systemctl enable --now power-profiles-daemon \
    && ok "power-profiles-daemon enabled." \
    || warn "power-profiles-daemon enable failed."
}

phase_lvfs() {
  step "[P8] LVFS firmware check..."
  if command -v fwupdmgr >/dev/null 2>&1; then
    fwupdmgr refresh --force \
      && fwupdmgr get-updates \
      && ok "LVFS checked." \
      || warn "No firmware updates or fwupd issue — skipping."
  else
    skip "fwupdmgr not found"
  fi
}

export _LIB_FEDORA_COMMON_LOADED=1
