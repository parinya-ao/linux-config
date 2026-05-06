# Driver Installation Scripts - Quick Reference

## What's New in v2.0?

✅ **Hardware Auto-Detection** - Detects NVIDIA (10de), Intel (8086), Hybrid Optimus
✅ **GPU Architecture Awareness** - Selects optimal drivers for your GPU generation
✅ **Secure Boot Support** - Automatic MOK key generation and enrollment (Ubuntu)
✅ **Zero Human Interaction** - Truly 100% automated installation
✅ **Hybrid Graphics** - Automatic power management for NVIDIA+Intel systems
✅ **Codec Stack** - Full multimedia with hardware acceleration

---

## Quick Start

### Choose Your Distro:

**Fedora:**

```bash
sudo bash /home/parinya/.config/home-manager/distro/fedora/fedora.sh
```

**Ubuntu:**

```bash
sudo bash /home/parinya/.config/home-manager/distro/ubuntu/ubuntu.sh
```

**openSUSE:**

```bash
sudo bash /home/parinya/.config/home-manager/distro/opensuse/opensuse.sh
```

---

## What Gets Installed?

### Always Installed:

- ✓ Latest system firmware & microcode updates
- ✓ PipeWire audio stack (replaces PulseAudio)
- ✓ FFmpeg with full codec support
- ✓ GStreamer multimedia plugins
- ✓ Power management & thermal throttling
- ✓ Firmware update tools (fwupd)
- ✓ Bluetooth stack

### If NVIDIA GPU Detected:

- ✓ NVIDIA proprietary driver (latest stable version)
- ✓ CUDA Toolkit (optional, for AI/ML)
- ✓ NVIDIA Power Management

### If Intel GPU Detected:

- ✓ Intel Media Driver (iHD) for hardware video acceleration
- ✓ VA-API support for encoding/decoding
- ✓ Hardware support for H.264, H.265, VP9, AV1

### If Hybrid Graphics Detected:

- ✓ nvidia-prime for GPU switching
- ✓ Automatic power profile management

---

## Multi-Round Installation Process

### Fedora:

```
Round 1 → Enable RPM Fusion repos → Re-run script
   ↓
Round 2 → Install NVIDIA driver (akmod) + Full stack
   ↓
Round 3 → Verify everything is installed (automatic)
```

### Ubuntu:

```
Round 1 → Enable restricted repos + base packages
   ↓
Round 2 → Install NVIDIA driver + Full stack
   ↓
Round 3 → Verify installation complete
```

### openSUSE:

```
Round 1 → Enable Packman repos → Re-run script
   ↓
Round 2 → Install NVIDIA driver + Full stack
   ↓
Round 3 → Verify installation complete
```

---

## Hardware Detection Output

After running, you'll see output like:

```
[INIT] Detecting graphics hardware...
[INFO] NVIDIA GPU detected:
       01:00.0 VGA: NVIDIA GeForce RTX 3080 [10de:2206]
[INFO] Intel iGPU detected:
       00:02.0 VGA: Intel UHD Graphics 630 [8086:3e9b]
[INFO] Hybrid Graphics Mode Detected (Optimus-like)
```

---

## Key Features by Distribution

### Fedora:

- **akmod-nvidia**: Automatically recompiles driver on kernel updates
- **First boot**: May take longer as akmod compiles the module
- **Automatic**: No manual intervention needed after installation

### Ubuntu:

- **Graphics PPA**: Access to latest stable drivers
- **Secure Boot**: Automatic MOK key handling
- **nvidia-prime**: Seamless GPU switching for laptops

### openSUSE:

- **Packman**: Curated multimedia codecs & drivers
- **G-Series**: Intelligent driver versioning (G05/G06/G07)
- **Tumbleweed/Leap**: Automatic detection and setup

---

## Verification Commands

```bash
# Check NVIDIA Driver
nvidia-smi

# Check Intel GPU Acceleration
vainfo

# Check Audio System (PipeWire)
pactl info

# Check Multimedia Codecs
ffmpeg -version

# Check Firmware Status
fwupdmgr get-updates

# Monitor GPU Temperature
nvidia-smi -l 1
```

---

## Common Scenarios

### I have NVIDIA GPU + Intel iGPU (Laptop):

- Both drivers automatically installed
- `nvidia-prime` enables GPU switching
- Intel iGPU for battery saving, NVIDIA for gaming

### I have Secure Boot enabled (Ubuntu):

- Script creates MOK key automatically
- On next reboot, blue screen appears
- Select "Enroll MOK" → Enter password → Reboot
- NVIDIA driver loads automatically

### I want CUDA for Machine Learning:

- Script attempts automatic installation
- Check: `nvidia-smi` (should show CUDA capability)
- Can install PyTorch/TensorFlow afterward

### Video Hardware Acceleration Not Working:

```bash
# Run this to verify:
vainfo

# If empty, ensure Intel Media Driver is installed:
# Ubuntu: intel-media-va-driver-non-free
# Fedora: intel-media-driver
# openSUSE: intel-media-driver from Packman
```

---

## Troubleshooting

### "nvidia-smi: command not found" after reboot:

- **Fedora**: akmod is still compiling. Wait 5-10 minutes, check: `sudo dmesg | grep nvidia`
- **Ubuntu**: Check driver installation: `dpkg -l | grep nvidia`
- **Solution**: Reboot again in a few minutes

### "Secure Boot prevents loading nvidia.ko" (Ubuntu):

- At blue MOK screen on reboot
- Select "Enroll MOK"
- Choose key
- Enter password (created by script)
- Reboot again

### Black screen after installation:

- **Likely cause**: nouveau driver still loaded
- **Fix**: Script blacklists nouveau, but may need manual purge
- Reboot and press Ctrl+Alt+F2, then:
  ```bash
  sudo rmmod nouveau
  sudo reboot
  ```

### 4K/High Resolution Video Slow:

- **Fix**: Intel Media Driver or NVIDIA Video Engine not active
- Check: `vainfo` (should show hardware capabilities)
- May require reboot after driver installation

---

## System Requirements

- **Fedora 38+** or **Ubuntu 22.04+** or **openSUSE Leap 15.5+**
- **UEFI firmware** (for Secure Boot handling)
- **Internet connection** (for package downloads)
- **Root/sudo access**
- **~2-3 GB free disk space**

---

## Recommended Post-Installation

1. **Reboot**: Essential for firmware and kernel module loading
2. **Update BIOS**: If available and newer than system
3. **Install Optional**:
   - Media codecs: `ubuntu-restricted-extras` (Ubuntu)
   - Development tools: CUDA samples, profilers
   - Gaming: Steam (automatically detects NVIDIA/Intel)

---

## Performance Tips

### For NVIDIA Users:

```bash
# Monitor real-time GPU usage
watch -n 1 nvidia-smi

# Set persistent mode (keeps GPU awake)
sudo nvidia-smi -pm 1
```

### For Intel iGPU Users:

```bash
# Monitor VA-API usage
libva-utils (provided)

# Test encoding performance
ffmpeg -i input.mp4 -c:v hevc_qsv output.mp4
```

### For Hybrid Graphics:

```bash
# Switch to NVIDIA (high performance)
prime-select nvidia

# Switch to Intel (battery saving)
prime-select intel

# Check current: cat /etc/prime-discrete
```

---

## Support Resources

- **Fedora**: https://docs.fedoraproject.org/
- **Ubuntu**: https://help.ubuntu.com/
- **openSUSE**: https://doc.opensuse.org/
- **NVIDIA**: https://www.nvidia.com/Download/driverDetails.aspx
- **Intel**: https://github.com/intel/media-driver

---

## Version & Updates

- **Current Version**: 2.0 (Hardware-Aware)
- **Released**: May 6, 2026
- **Location**: `/home/parinya/.config/home-manager/distro/`

For detailed documentation, see: `DRIVER_UPDATES.md`

---

**Remember**: The script is designed to be 100% automated. Trust the process, reboot when asked, and verify with the commands above.

Good luck! 🚀
