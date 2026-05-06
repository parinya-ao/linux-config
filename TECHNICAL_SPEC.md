# Technical Specification - Graphics Driver Architecture

**Version:** 2.0
**Architecture Level:** Advanced (Expert)
**Target Audience:** System Administrators, DevOps Engineers, Advanced Users

---

## 1. Hardware Detection Architecture

### 1.1 GPU Detection via PCI Bus Enumeration

All scripts use `lspci -nn` for authoritative hardware identification:

```bash
detect_nvidia_gpu() {
  lspci -nn | grep -i "10de:" | grep -iE "vga|3d|display"
}
```

**Why `lspci -nn`?**

- Provides numeric output with vendor/device IDs in brackets `[10de:1be0]`
- `10de` = NVIDIA (globally registered PCI vendor ID)
- `8086` = Intel
- Works across all systems (BIOS/UEFI)

**Grep Filters:**

- `-i` = Case-insensitive
- `10de:` = NVIDIA devices only
- `vga|3d|display` = Filter graphics devices

### 1.2 Vendor ID Registry

```
Vendor ID  | Manufacturer         | Detection Variable
-----------|----------------------|-------------------
10de       | NVIDIA Corporation   | NVIDIA_DETECTED
8086       | Intel Corporation    | INTEL_DETECTED
1002       | AMD (Radeon/EPYC)    | Reserved for v3.0
1022       | AMD (Ryzen, future)  | Reserved for v3.0
```

### 1.3 Hybrid Graphics Detection Algorithm

```bash
detect_hybrid_graphics() {
  if detect_nvidia_gpu >/dev/null 2>&1 && detect_intel_gpu >/dev/null 2>&1; then
    return 0  # Both present = Hybrid mode
  fi
  return 1
}
```

**Detection Pattern:**

```
System → lspci → Check for 10de (NVIDIA)
       → lspci → Check for 8086 (Intel)
       → If both found → HYBRID_MODE=true
```

**Real-World Examples:**

- Dell XPS 15 (Optimus): UHD 630 + RTX 3080
- ASUS Gaming Laptop: UHD Graphics + RTX 4070
- MacBook Pro (if running Linux): Iris GPU + Radeon (if eGPU)

---

## 2. NVIDIA Driver Architecture by Distribution

### 2.1 Fedora: akmod (Automatic Kernel Module)

#### Architecture:

```
Fedora Core
    ↓
akmod-nvidia package installed
    ↓
akmods service monitors kernel version
    ↓
On kernel update detected:
    ├─ Extract source from installed package
    ├─ Run NVIDIA driver compiler (nvbuild)
    ├─ Link against new kernel headers
    └─ Automatically insmod new nvidia.ko
    ↓
Zero manual intervention!
```

#### Implementation:

```bash
dnf_install akmod-nvidia nvidia-driver-libs nvidia-driver-libs.i686

# Blacklist nouveau to prevent conflicts
echo "blacklist nouveau" | tee /etc/modprobe.d/nvidia-disable-nouveau.conf
echo "options nouveau modeset=0" >> /etc/modprobe.d/nvidia-disable-nouveau.conf
```

#### Why akmod?

- Automatic on every kernel update
- No manual `dkms rebuild` needed
- Works with Fedora's rapid release cycle
- First boot takes longer (~5-10 min) for compilation

### 2.2 Ubuntu: DKMS + Graphics PPA

#### Architecture:

```
Ubuntu Kernel
    ↓
Graphics PPA adds latest drivers
    ↓
apt install nvidia-driver-XXX
    ↓
DKMS auto-detects kernel update
    ↓
Manual rebuild (but predictable)
    ↓
MOK key signing if Secure Boot enabled
```

#### Implementation:

```bash
add-apt-repository -y ppa:graphics-drivers/ppa
apt-get update -y

# Auto-detect latest driver version
LATEST_NVIDIA_DRIVER=$(apt-cache search '^nvidia-driver-[0-9]+$' \
  | grep -oP 'nvidia-driver-\K[0-9]+' | tail -1)

apt_install nvidia-driver-${LATEST_NVIDIA_DRIVER}
```

#### Version Detection Logic:

```bash
# Example output:
# nvidia-driver-515    # Older LTS
# nvidia-driver-535    # Current LTS
# nvidia-driver-550    # Latest stable

# Script takes LAST (most recent)
tail -1 → nvidia-driver-550
```

### 2.3 openSUSE: G-Series + Packman

#### G-Series Architecture:

```
GPU Architecture    | G-Series | Driver Version | Support Status
--------------------|----------|----------------|----------------
Kepler (GTX 700s)   | G03/G04  | v340/v390     | Dropped (EOL)
Kepler → Maxwell    | G05      | v470          | Legacy (stable)
Maxwell/Pascal      | G06      | v550/v580     | Recommended
Turing+             | G07      | v595+         | Latest (preferred)
```

#### Implementation:

```bash
# Simplified (default to G06 for broad compatibility)
NVIDIA_G_SERIES="G06"

zypper_install "nvidia-driver-${NVIDIA_G_SERIES}" \
               nvidia-driver-libs \
               nvidia-kmp-default

# For modern systems, could auto-detect:
# if [[ GPU_ARCH == "turing" ]] || [[ GPU_ARCH == "ampere" ]]; then
#   NVIDIA_G_SERIES="G07"
# fi
```

#### Why Packman?

- Curated repository trusted by openSUSE community
- Handles licensing restrictions
- Pre-built packages (faster than from-source)
- Includes firmware and multimedia codecs

---

## 3. Intel Media Driver Selection Algorithm

### 3.1 Detection Strategy

```
CPU Model Detection (lscpu)
    ↓
Extract Generation (Gen 5-15)
    ↓
If Gen ≥ 8 (Broadwell+):
    ├─ Install intel-media-driver (iHD) ← Modern
    ├─ Install libva2
    └─ Full hardware acceleration available
    ↓
If Gen < 8 (legacy):
    ├─ Install libva-intel-driver (i965) ← Fallback
    └─ Basic VA-API support
```

### 3.2 Generation Mapping

```
Generation | CPU Model       | GPU Arch    | Media Driver    | Notes
-----------|-----------------|-------------|-----------------|----------
5th Gen    | Broadwell      | Iris Xe     | i965/iHD        | Transition
6th Gen    | Skylake        | Iris Xe     | iHD preferred   | Modern
7th Gen    | Kaby Lake      | Iris Xe     | iHD             | Better support
8th Gen    | Coffee Lake    | Iris Xe     | iHD full        | Recommended
9th Gen    | Coffee Lake R  | Iris Xe     | iHD full        | Solid
10th Gen   | Ice Lake       | Iris Xe Plus| iHD full        | High-end
11th Gen   | Tiger Lake     | Iris Xe     | iHD full        | Laptop focus
12th Gen   | Alder Lake     | Iris Xe     | iHD full        | Latest LTS era
13th Gen   | Raptor Lake    | Iris Xe     | iHD full        | Ultra-modern
14th Gen   | Raptor Lake R  | Iris Xe     | iHD full        | Currently shipping
15th Gen+  | Arrow Lake     | Iris 200+   | iHD future      | Next-gen
```

### 3.3 Codec Support by Media Driver

#### intel-media-driver (iHD):

- **Decode**: AVC, HEVC (8/10/12-bit), VP9, AV1, VVC (future)
- **Encode**: QuickSync (H.264, HEVC, VP9, AV1)
- **Process**: VEBox (deinterlacing), SFC (scaling)
- **Performance**: Hardware acceleration for 4K/8K

#### libva-intel-driver (i965, legacy):

- **Decode**: AVC, MPEG2
- **Encode**: Limited
- **Performance**: Lower bitrate efficiency

---

## 4. Secure Boot & MOK Integration (Ubuntu)

### 4.1 Secure Boot State Detection

```bash
detect_secure_boot_status() {
  if [[ -f /sys/firmware/efi/fw_platform_size ]]; then
    # UEFI system detected
    if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
      return 0  # Secure Boot is ON
    fi
  fi
  return 1  # Secure Boot is OFF or BIOS mode
}
```

**Detection Hierarchy:**

1. Check `/sys/firmware/efi/fw_platform_size` → UEFI present?
2. Call `mokutil --sb-state` → Secure Boot state?
3. Parse output for "SecureBoot enabled"

### 4.2 MOK Key Generation Flow

```bash
# Step 1: Create key directory
mkdir -p /var/lib/dkms/mok/{private,public}

# Step 2: Generate self-signed X.509 certificate
openssl req -new -x509 -newkey rsa:2048 \
  -keyout /var/lib/dkms/mok/private/mok.key \
  -outform DER \
  -out /var/lib/dkms/mok/public/mok.der \
  -nodes -days 36500 \
  -subj "/CN=NVIDIA Driver Signing Key/"

# Step 3: Import into MOK list (non-interactive with password)
mokutil --import /var/lib/dkms/mok/public/mok.der \
  --password=<temporary_password>
```

### 4.3 User Workflow with MOK Enrollment

```
[Script runs]
    ↓
Creates MOK key pair
    ↓
Imports MOK to pending list
    ↓
"Please reboot to complete MOK enrollment"
    ↓
[User reboots] ← Only user action needed
    ↓
[Blue MOK screen appears]
    ↓
Select "Enroll MOK"
    ↓
Confirm → Reboot
    ↓
NVIDIA driver now loads with signed kernel module
    ↓
[Normal boot with GPU acceleration]
```

### 4.4 Key Signing Process

```
NVIDIA Driver Source
    ↓
Compile to nvidia.ko
    ↓
sign-file utility with MOK private key
    ↓
Signed nvidia.ko (accepts Secure Boot verification)
    ↓
Kernel loads module on boot
```

---

## 5. State Detection Matrix

### 5.1 Fedora State Variables

```
State Variable           | Detection Method              | Phase Flow
-------------------------|-------------------------------|------------------
RPM_FUSION_ACTIVE       | rpm -q rpmfusion-free-release | ROUND 1 → 2
FFMPEG_ACTIVE           | rpm -q ffmpeg                 | ROUND 2 done?
NVIDIA_DETECTED         | lspci -nn [10de:]             | Hardware scan
NVIDIA_DRIVER_ACTIVE    | rpm -q akmod-nvidia           | NVIDIA installed?
HYBRID_MODE             | lspci (both 10de/8086)        | GPU config
```

### 5.2 Ubuntu State Variables

```
State Variable           | Detection Method              | Phase Flow
-------------------------|-------------------------------|------------------
RESTRICTED_ACTIVE       | dpkg -l ubuntu-restricted     | ROUND 1 → 2
FFMPEG_ACTIVE           | dpkg -l ffmpeg                | ROUND 2 done?
GSTREAMER_ACTIVE        | dpkg -l gstreamer1.0-*        | Full codec support
NVIDIA_DETECTED         | lspci -nn [10de:]             | Hardware scan
NVIDIA_DRIVER_ACTIVE    | dpkg -l nvidia-driver-*       | Driver installed?
SECURE_BOOT_ENABLED     | mokutil --sb-state            | Reboot needed?
```

### 5.3 openSUSE State Variables

```
State Variable           | Detection Method              | Phase Flow
-------------------------|-------------------------------|------------------
PACKMAN_ACTIVE          | zypper repos (grep packman)   | ROUND 1 → 2
FFMPEG_ACTIVE           | rpm -q ffmpeg                 | ROUND 2 done?
NVIDIA_DETECTED         | lspci -nn [10de:]             | Hardware scan
NVIDIA_DRIVER_ACTIVE    | rpm -q nvidia-driver          | Driver installed?
IS_TUMBLEWEED           | /etc/os-release ID check      | Repo selection
IS_LEAP                 | /etc/os-release ID check      | Packman URL
```

---

## 6. Phase Dependency Graph

```
PRE-CHECK
    ├─ Root permission?
    ├─ Correct distro?
    └─ Hardware available?
    ↓
[PHASE 0] System Refresh
    ├─ apt-get update / dnf refresh / zypper refresh
    ├─ System upgrade
    └─ Repository setup
    ↓
[PHASE 0.5] NVIDIA Driver (if detected)
    ├─ Fedora: akmod-nvidia compilation
    ├─ Ubuntu: DKMS + Secure Boot MOK
    └─ openSUSE: G-Series from Packman
    ↓
[PHASE 1] Base Firmware (free)
    ├─ CPU microcode (intel-microcode, amd64-microcode)
    ├─ Generic linux-firmware
    └─ fwupd daemon
    ↓
[PHASE 2] Non-free Firmware
    ├─ Broadcom WiFi (if applicable)
    ├─ Bluetooth firmware
    └─ Audio (SOF) firmware
    ↓
[PHASE 3] Intel GPU + VA-API (if detected)
    ├─ intel-media-driver (Gen 8+)
    ├─ libva2, libva-utils
    └─ Mesa Vulkan
    ↓
[PHASE 4] Audio Stack
    ├─ SOF firmware
    └─ PipeWire full replacement
    ↓
[PHASE 5] Multimedia Codecs
    ├─ FFmpeg (full version with Packman/RPM Fusion)
    ├─ GStreamer plugins (good/bad/ugly)
    └─ libdvdcss2 (DVD CSS support)
    ↓
[PHASE 6-10] Hardware Support + Cleanup
    ├─ Bluetooth, Power, Printers, etc.
    └─ Final system cleanup
    ↓
COMPLETION
    └─ Reboot recommended
```

---

## 7. Error Handling Strategy

### 7.1 Non-Fatal Error Recovery

```bash
# Pattern: Try install, warn on failure, continue
zypper_install() {
  zypper --non-interactive install --no-recommends "$@" \
    && ok "Installed: $*" \
    || warn "Some packages unavailable — continuing"

  # Don't exit - script continues
  return 0
}
```

**Rationale:**

- Some packages may not exist in all distro versions
- Missing optional package shouldn't fail entire installation
- User still gets core functionality

### 7.2 Fatal Error Conditions

```bash
fail() {
  echo -e "${RED}[FAIL]${RESET} $*"
  exit 1  # Stop immediately
}

# Fatal checks:
[[ $EUID -ne 0 ]] && fail "Must run as root"
command -v dnf &>/dev/null || fail "dnf not found (Fedora only)"
! grep -qi "ubuntu" /etc/os-release && fail "Ubuntu only script"
```

### 7.3 API Mismatch Detection (Future)

```bash
# Proposed post-installation verification:
nvidia_api_check() {
  if nvidia-smi &>/dev/null; then
    DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
    MODULE_VERSION=$(modinfo nvidia | grep version | head -1)

    if [[ "$DRIVER_VERSION" != "$MODULE_VERSION" ]]; then
      warn "API Mismatch: Driver v${DRIVER_VERSION} != Module v${MODULE_VERSION}"
      warn "Consider reboot or recompilation"
    fi
  fi
}
```

---

## 8. Performance Implications

### 8.1 Installation Time Estimates

```
Distribution | Network | First Run | Subsequent | Reboot
-------------|---------|-----------|------------|--------
Fedora       | Slow    | 45-60 min | 20-30 min  | 10-15 min
             | Fast    | 20-30 min | 10-15 min  | 5-10 min
Ubuntu       | Slow    | 30-45 min | 15-20 min  | 5-10 min
             | Fast    | 15-20 min | 8-12 min   | 3-5 min
openSUSE     | Slow    | 35-50 min | 18-25 min  | 8-12 min
             | Fast    | 18-25 min | 10-15 min  | 4-8 min
```

**Variables:**

- Download speed (codecs + drivers are large)
- CPU cores (parallel compilation with akmod/dkms)
- Disk I/O (SSD vs HDD)

### 8.2 Disk Space Requirements

```
Component              | Fedora | Ubuntu | openSUSE
----------------------|--------|--------|----------
Base system updates    | 500MB  | 400MB  | 450MB
NVIDIA driver source   | 800MB  | 600MB  | 700MB
Multimedia codecs      | 200MB  | 180MB  | 250MB
Firmware              | 300MB  | 280MB  | 300MB
Build tools (dkms)    | 200MB  | 150MB  | 150MB
─────────────────────────────────────────────────
Total Minimum         | 2GB    | 1.6GB  | 1.8GB
Recommended Buffer    | +1GB   | +1GB   | +1GB
```

---

## 9. Configuration & Customization

### 9.1 Fedora G-Series Override

Current default (G06, recommended for Maxwell/Pascal):

```bash
# To force specific version, edit script:
NVIDIA_G_SERIES="G06"  # Maxwell/Pascal

# Alternative options:
# NVIDIA_G_SERIES="G05"  # Kepler (legacy, stable)
# NVIDIA_G_SERIES="G07"  # Turing+ (latest, bleeding-edge)
```

### 9.2 Ubuntu Graphics PPA Disable

To use only Ubuntu repos (slower driver updates):

```bash
# Comment out PPA addition:
# add-apt-repository -y ppa:graphics-drivers/ppa
# apt-get update -y

# Will default to ubuntu-provided nvidia-driver
```

### 9.3 openSUSE Repository Mirrors

To use faster mirror:

```bash
PACKMAN_REPO="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/Essentials/"

# Alternative mirrors:
# PACKMAN_REPO="https://packman.inode.at/suse/openSUSE_Tumbleweed/Essentials/"
# PACKMAN_REPO="https://mirror.example.com/packman/suse/..."
```

---

## 10. Future Enhancement Roadmap

### v3.0 (Planned):

- [ ] AMD GPU detection & driver installation
- [ ] Automatic NVIDIA G-series detection
- [ ] Intel Arc (Xe) discrete GPU support
- [ ] Comprehensive logging with timestamps
- [ ] Rollback capability on critical failures
- [ ] Container runtime GPU support (Docker, Podman)
- [ ] Machine Learning stack auto-detection
- [ ] Performance profiling suite

### v2.1 (Minor):

- [ ] Improved error messages
- [ ] Installation resumption if interrupted
- [ ] Better Secure Boot status reporting
- [ ] More comprehensive verification tests

---

## 11. Testing Methodology

### 11.1 Pre-Deployment Testing

```
Test Environment → Ubuntu VM + Secure Boot enabled
                ├─ NVIDIA GPU passthrough via vfio
                ├─ Intel iGPU
                └─ Hybrid graphics simulation

Test Case 1: Fresh installation, all phases
Test Case 2: Round 2 (repositories already enabled)
Test Case 3: Round 3 (already installed)
Test Case 4: Secure Boot MOK enrollment
Test Case 5: akmod compilation (Fedora only)
```

### 11.2 Verification Checklist

```
✓ nvidia-smi returns GPU info
✓ vainfo shows VA-API acceleration
✓ ffmpeg lists all encoders/decoders
✓ pactl shows PipeWire daemon active
✓ 4K video plays smoothly (20-30% CPU)
✓ CUDA runs (if installed)
✓ Prime GPU switching works (hybrid systems)
✓ Thermal monitoring available
✓ fwupd detects available firmware
✓ No DRI conflicts or missing drivers
```

---

## 12. Architecture Diagrams

### 12.1 Installation State Machine

```
┌─────────────┐
│ START: v2.0 │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│ Hardware Detect  │
│ NVIDIA? Intel?   │
│ Hybrid?          │
└─────┬──────┬─────┘
      │      │
      ▼      ▼
  [10de]   [8086]
      │      │
      ▼      ▼
┌──────────────────┐
│ PHASE 0: System  │
│ Refresh & Repos  │
└────────┬─────────┘
         │
    ┌────┴─────┐
    │           │
    ▼           ▼
[NVIDIA]    [Intel Media]
    │           │
    ├─akmod     ├─iHD
    ├─DKMS      ├─libva
    └─MOK       └─VA-API
    │           │
    └───┬───────┘
        │
        ▼
┌──────────────────┐
│ PHASES 1-10      │
│ Full codec stack │
│ Audio, Power,etc │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ COMPLETE        │
│ Reboot required │
└─────────────────┘
```

---

## References

- Linux PCI Framework: https://www.kernel.org/doc/Documentation/PCI/
- NVIDIA Driver Architecture: https://github.com/NVIDIA/driver/
- Intel Media Driver: https://github.com/intel/media-driver
- VA-API Documentation: https://github.com/intel/libva
- Secure Boot MOK: https://github.com/luto/mokutil
- akmod Documentation: https://pagure.io/akmod/

---

**Version:** 2.0 | **Last Updated:** May 6, 2026 | **Status:** Production Ready
