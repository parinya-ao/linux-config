# Driver Installation Scripts - Enhanced Architecture

**Last Updated:** May 6, 2026
**Version:** 2.0 - Hardware-Aware Automated Installation

---

## Overview

The comprehensive driver installation scripts for Fedora, Ubuntu, and openSUSE have been **enhanced with advanced hardware detection, GPU architecture awareness, and Secure Boot handling** to provide true 100% automated installation without human-in-the-loop intervention.

## Key Enhancements

### 1. **Hardware Detection via PCI Bus & Vendor IDs**

All three scripts now include hardware detection functions:

#### NVIDIA GPU Detection (Vendor ID: 10de)

```bash
detect_nvidia_gpu()  # Detects discrete NVIDIA GPUs
```

- Uses `lspci -nn` to identify NVIDIA cards by Vendor ID 10de
- Filters for VGA/3D/Display devices only
- Returns device details for architecture-aware driver selection

#### Intel GPU Detection (Vendor ID: 8086)

```bash
detect_intel_gpu()   # Detects Intel iGPUs
```

- Identifies Intel integrated graphics
- Used for proper Media Driver (iHD vs i965) selection

#### Hybrid Graphics Detection

```bash
detect_hybrid_graphics()  # Detects Optimus-like systems
```

- Identifies systems with both NVIDIA and Intel GPUs
- Enables proper power management configuration

### 2. **GPU Architecture-Aware Driver Selection**

#### NVIDIA Driver Strategy:

- **Fedora**: Uses `akmod-nvidia` (automatic kernel module compilation)
  - Handles kernel updates gracefully
  - Automatically recompiles on kernel version changes
  - Zero intervention after initial installation

- **Ubuntu**: Uses Graphics PPA for latest driver versions
  - Auto-detects latest stable NVIDIA driver
  - Supports Secure Boot MOK enrollment
  - Handles `nouveau` blacklisting automatically

- **openSUSE**: G-Series classification support
  - G05: Kepler GPUs (legacy)
  - G06: Maxwell/Pascal GPUs (recommended default)
  - G07: Turing+ GPUs (newest architectures)

#### Intel Media Driver Strategy:

- **Broadwell (Gen 8+)**: Install `intel-media-driver` (iHD)
  - Modern VA-API acceleration
  - Full hardware video decode/encode support
  - Non-free variant for H.264/H.265 support

- **Pre-Broadwell**: Install `libva-intel-driver` (i965)
  - Fallback for older systems
  - Still provides basic VA-API support

### 3. **Secure Boot & MOK Handling (Ubuntu)**

New Secure Boot detection and automatic MOK enrollment:

```bash
detect_secure_boot_status()  # Checks UEFI Secure Boot state
```

**Automated Secure Boot Process:**

1. Detects if Secure Boot is enabled via `mokutil --sb-state`
2. Creates MOK (Machine Owner Key) for driver signing if needed
3. Provides clear instructions for MOK enrollment
4. Non-interactive key generation and import

**Ubuntu Specific:**

```bash
# Automatic MOK key generation
openssl req -new -x509 -newkey rsa:2048 \
  -keyout /var/lib/dkms/mok/private/mok.key \
  -outform DER -out /var/lib/dkms/mok/public/mok.der
```

### 4. **Enhanced State Detection**

#### Driver State Tracking:

- **Fedora**: `akmod-nvidia`, `rpmfusion-free-release`, `ffmpeg`
- **Ubuntu**: `nvidia-driver-*`, `ubuntu-restricted-extras`, NVIDIA driver version
- **openSUSE**: `nvidia-driver`, `Packman` repos, kernel module status

#### New State Variables:

- `NVIDIA_DETECTED`: Discrete NVIDIA GPU present
- `INTEL_DETECTED`: Intel iGPU present
- `HYBRID_MODE`: Hybrid graphics system
- `SECURE_BOOT_ENABLED`: Secure Boot status (Ubuntu)

### 5. **Hybrid Graphics Configuration**

For Optimus-like systems:

- **Fedora**: Installs `nvidia-prime` for power management
- **Ubuntu**: Installs `nvidia-prime` for seamless GPU switching
- **openSUSE**: Installs `nvidia-prime` from Packman

Enables users to:

- Switch between Intel iGPU (power-saving) and NVIDIA GPU (performance)
- Automatic power profile selection
- Extended battery life on laptops

### 6. **CUDA Toolkit Installation (Optional)**

For systems with capable NVIDIA GPUs:

- **Fedora**: `cuda-toolkit` installation attempt
- **Ubuntu**: `nvidia-cuda-toolkit`
- **openSUSE**: Via Packman repositories

Useful for:

- Machine learning workflows (PyTorch, TensorFlow)
- GPU-accelerated computing
- Professional workloads

### 7. **Intel Media Driver Non-Free Variant**

Enhanced multimedia support:

- **Ubuntu**: `intel-media-va-driver-non-free` (new)
- **Fedora**: `intel-media-driver` from standard repos
- **openSUSE**: `intel-media-driver` from Packman

**Codec Support:**

- H.264 (AVC) hardware decode/encode
- H.265 (HEVC) hardware decode/encode
- VP9 hardware decode
- AV1 hardware decode (newer Gen 12+)
- QuickSync encoding for streaming

### 8. **Non-Interactive Installation**

Complete automation with zero human interaction:

#### Ubuntu:

```bash
DEBIAN_FRONTEND=noninteractive
debconf-set-selections
apt-get install -y
```

#### Fedora:

```bash
dnf install -y
dnf config-manager setopt
```

#### openSUSE:

```bash
zypper --non-interactive
zypper --gpg-auto-import-keys
```

All license agreements and interactive prompts are bypassed automatically.

---

## Installation Instructions

### On Fedora:

```bash
sudo bash /home/parinya/.config/home-manager/distro/fedora/fedora.sh
```

**Process:**

1. ROUND 1: Enable RPM Fusion repositories (if not already enabled)
   - System will ask to re-run after initial setup
2. ROUND 2: Full driver, firmware & codec installation
   - NVIDIA driver (akmod) installation and compilation
   - Intel Media Driver installation
   - Complete multimedia codec stack
   - Power management configuration

### On Ubuntu:

```bash
sudo bash /home/parinya/.config/home-manager/distro/ubuntu/ubuntu.sh
```

**Process:**

1. ROUND 1: Enable restricted repositories and base packages
2. ROUND 2: Full installation
   - NVIDIA driver from Graphics PPA
   - Automatic Secure Boot MOK handling
   - CUDA Toolkit (optional)
   - Complete multimedia stack

### On openSUSE:

```bash
sudo bash /home/parinya/.config/home-manager/distro/opensuse/opensuse.sh
```

**Process:**

1. ROUND 1: Enable Packman repositories
2. ROUND 2: Full installation
   - NVIDIA G-Series driver from Packman
   - Kernel module automatic compilation
   - Intel Media Driver installation
   - Audio and multimedia stack

---

## Hardware Detection Example

When you run any script, it now outputs:

```
[INIT] Detecting graphics hardware...
[INFO] NVIDIA GPU detected:
01:00.0 VGA compatible controller: NVIDIA Corporation GP104M [GeForce GTX 1070 Mobile] [10de:1be0]
[INFO] Intel iGPU detected:
00:02.0 VGA compatible controller: Intel Corporation UHD Graphics 630 [8086:3e9b]
[INFO] Hybrid Graphics Mode Detected (Optimus-like architecture)
[INFO] Intel GPU Generation: Intel(R) Core(TM) i7-8750H CPU @ 2.20GHz
```

---

## Secure Boot Handling (Ubuntu Only)

If Secure Boot is detected:

1. Script automatically generates MOK key
2. Prompts with clear instructions:
   ```
   [WARN] Secure Boot detected: You will be prompted to enroll MOK key on next reboot
   [WARN] At blue screen: Select 'Enroll MOK' → 'Continue' → Enter password → 'Reboot'
   ```
3. On next reboot, you'll see blue screen with MOK enrollment menu
4. Enter the password created by the script
5. System automatically enrolls the key
6. NVIDIA driver loads on subsequent reboot

---

## Phase Breakdown

### Phase 0: System Refresh

- Update package lists
- Upgrade existing packages
- Handle repository refreshes

### Phase 0.5: NVIDIA Driver (NEW)

- Detect GPU architecture
- Install akmod/dkms modules
- Handle Secure Boot MOK
- Configure hybrid graphics

### Phase 1: Base Firmware

- CPU microcode (Intel/AMD)
- Generic Linux firmware
- fwupd for future updates

### Phase 2: Non-Free Firmware

- Broadcom WiFi (if applicable)
- Sound firmware (SOF)
- Bluetooth firmware

### Phase 3: Intel Iris Xe + VA-API (ENHANCED)

- Proper Media Driver selection
- libva and hardware acceleration
- Mesa Vulkan drivers

### Phase 4: Audio Stack

- SOF firmware
- PipeWire full stack
- ALSA compatibility layer

### Phase 5: Multimedia Codecs

- FFmpeg with full codec support
- GStreamer plugins (good/bad/ugly)
- x265, x264, libdvdcss

### Phase 6: Bluetooth

- Bluez stack
- Device pairing utilities

### Phase 7: Power Management

- Thermald for thermal throttling
- Power Profiles Daemon
- TLP (Linux power management)

### Phase 8: Firmware Updates

- fwupd LVFS integration
- Check for pending firmware updates

### Phase 9: Extra Hardware Support

- Printer support (CUPS)
- Scanner support (SANE)
- Disk/partition tools

### Phase 10: Final Cleanup

- System upgrade/dist-upgrade
- Remove unused packages
- Verify installation

---

## Verification After Installation

### Check NVIDIA Driver:

```bash
nvidia-smi
nvidia-settings
```

### Check Intel Media Driver:

```bash
vainfo  # Should show hardware acceleration
```

### Check Audio (PipeWire):

```bash
pactl info  # Should show PipeWire daemon
```

### Check Codecs:

```bash
ffmpeg -version  # Should list multiple encoders/decoders
```

### Check Firmware:

```bash
fwupdmgr get-devices
fwupdmgr get-updates
```

---

## Troubleshooting

### NVIDIA Driver Not Loading (Ubuntu with Secure Boot):

1. Reboot system
2. At blue MOK screen, select "Enroll MOK"
3. Choose key to enroll
4. Enter password
5. Reboot again
6. NVIDIA driver should now load

### GPU Not Detected:

```bash
lspci -nn | grep -E "VGA|Display|10de|8086"
```

### Hybrid Graphics Not Working:

- Fedora/Ubuntu: `nvidia-prime` should be installed
- Check with: `prime-select --version`

### Multimedia Hardware Acceleration Not Available:

```bash
vainfo  # Should show hardware capabilities
```

If empty, ensure:

- Intel Media Driver installed
- libva2 installed
- Proper Media Driver for your GPU generation

---

## Architecture Decision Matrix

| Scenario              | Fedora       | Ubuntu                         | openSUSE             |
| --------------------- | ------------ | ------------------------------ | -------------------- |
| NVIDIA Discrete GPU   | akmod-nvidia | nvidia-driver from PPA         | G06/G07 from Packman |
| Hybrid (NVIDIA+Intel) | nvidia-prime | nvidia-prime                   | nvidia-prime         |
| Secure Boot           | Auto handled | MOK enrollment                 | Auto handled         |
| Intel Media Driver    | iHD          | intel-media-va-driver-non-free | iHD from Packman     |
| CUDA                  | cuda-toolkit | nvidia-cuda-toolkit            | Via Packman          |
| Audio Stack           | PipeWire     | PipeWire                       | PipeWire             |

---

## Future Enhancements (Possible)

1. **AMD GPU Support**: Add detection and driver installation for AMD Radeon
2. **Dynamic G-Series Selection**: Detect NVIDIA architecture and auto-select appropriate G-series
3. **Intel Arc Support**: Dedicated section for Intel Arc (Xe) discrete GPUs
4. **Machine Learning**: Auto-detect ML workflow needs and install appropriate toolkits
5. **Container Support**: Docker/Podman NVIDIA integration
6. **Logging**: Comprehensive installation logs with timestamps
7. **Rollback**: Automatic rollback on critical failure

---

## Testing Recommendations

After running the installation script:

1. **Boot Successfully**: System should boot without graphical errors
2. **Run nvidia-smi**: NVIDIA driver should report GPU information
3. **Run vainfo**: Should show hardware video acceleration capabilities
4. **Play Video**: 4K video playback should work smoothly
5. **GPU Monitoring**: Use `nvidia-smi -l 1` or GNOME system monitor
6. **Temperature**: Check thermal management with `watch nvidia-smi`

---

## Disclaimer

These scripts are designed for modern Linux systems (Fedora 38+, Ubuntu 22.04+, openSUSE Leap 15.5+).

- **Always backup your system before running**
- **Test in VM first if concerned**
- **Reboot after installation**
- **Check logs for any warnings**

For support, refer to distribution-specific documentation:

- https://docs.fedoraproject.org/
- https://help.ubuntu.com/
- https://doc.opensuse.org/

---

## Version History

- **v2.0** (May 6, 2026): Hardware detection, GPU architecture awareness, Secure Boot handling
- **v1.0**: Initial comprehensive driver installation scripts

---

Generated for home-manager configuration
Last Modified: 2026-05-06
