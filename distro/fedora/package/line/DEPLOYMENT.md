# LINE Wine Installer — Complete Deployment Package

## What Was Refactored

The original `line_wine_install.sh` (menu-driven, hardcoded colors, basic error handling) has been completely refactored using the **gum-bash design system** to create `line_wine_install_refactored.sh`.

### Files in This Package

| File | Purpose |
|------|---------|
| `line_wine_install_refactored.sh` | Main installer (production-ready) |
| `REFACTORING_GUIDE.md` | Design changes, architecture, improvements |
| `GUM_BASH_QUICK_REF.md` | Gum-bash patterns used in this script |
| `LINE_TROUBLESHOOTING.md` | Three-layer troubleshooting for LINE on Wine |
| `FIX_SUMMARY.md` | Prior fixes applied (gum flag parsing, WINEDEBUG) |
| `DEPLOYMENT.md` | This file — integration instructions |

---

## Key Improvements

### 1. Automated Path Detection (Layer 2 Fix)
If LINE installer places launcher in unexpected path, script now auto-detects all known locations:
```bash
find_line_launcher()  # Searches 5+ standard paths + fallback to full find
```

### 2. CRYPT32 Signature Issue Handling (Layer 3 Fix)
Built-in menu option to apply DLL override for LINE's signature verification:
```bash
"🔧 Fix CRYPT32 Signature Issue" → "Set builtin crypt32 override"
```

### 3. Terminal Cleanliness (Layer 1 Fix)
Wine debug spam is automatically suppressed:
```bash
export WINEDEBUG="-fixme"  # In CONFIG section
```

### 4. Gum-Bash Architecture
- **Layer 1 (UI)**: 8 primitives (banner, step, ok, warn, fail, info, kv, section_header)
- **Layer 2 (Runners)**: 2 helpers (run_step, run_sudo_step with spinners)
- **Layer 3 (Tasks)**: 10 idempotent functions (install, setup, launch, fix, reset, etc.)
- **Layer 4 (Orchestration)**: Pipeline + menu (gum choose instead of raw read)

### 5. Semantic Color Tokens
Change theme once, entire script updates:
```bash
readonly C_PRIMARY="#00BFFF"      # Headers
readonly C_SUCCESS="#04B575"      # ✔ ok
readonly C_WARNING="#FFA500"      # ⚠ cautions
readonly C_DANGER="#FF4500"       # ✖ errors
```

---

## Installation & Usage

### Quick Start

```bash
chmod +x ~/.config/home-manager/distro/fedora/package/line/line_wine_install_refactored.sh
~/.config/home-manager/distro/fedora/package/line/line_wine_install_refactored.sh
```

### Menu Options

```
LINE DESKTOP INSTALLER (WINE 64-BIT)

1. 📦 Install System Wine (auto-detect dnf/apt)
   → Removes old Wine, installs new from package manager
   
2. ⚙️  Setup Wine Prefix & Install LINE
   → Creates prefix, runs winecfg, installs runtimes, runs LINE installer
   
3. ▶️  Launch LINE
   → Auto-detects launcher path, starts LINE
   
4. 🔧 Fix CRYPT32 Signature Issue (Layer 3)
   → Sets DLL override for Microsoft signature verification
   
5. ⏹️  Kill LINE Processes
   → Force terminate Wine/LINE (if hung or stuck)
   
6. 🗑️  Reset/Remove LINE Prefix
   → Destructive: deletes all LINE data and Wine prefix
   
7. ℹ️  Show Summary
   → Displays Wine version, prefix location, installation status
   
8. ❌ Exit
```

---

## Integration with Home Manager

### Option A: Add to PATH via Home Manager

Add to `modules/programs/fish.nix` (or equivalent):

```nix
{
  programs.fish.shellAliases = {
    line-install = "~/.local/bin/line-wine-installer";
  };
  
  home.file.".local/bin/line-wine-installer" = {
    source = ./distro/fedora/package/line/line_wine_install_refactored.sh;
    executable = true;
  };
}
```

Then run: `home-manager switch`

### Option B: Standalone Execution

```bash
# Direct path
~/.config/home-manager/distro/fedora/package/line/line_wine_install_refactored.sh

# Or create symlink
ln -s ~/.config/home-manager/distro/fedora/package/line/line_wine_install_refactored.sh \
      ~/.local/bin/line-install
```

---

## Testing Before Deployment

### Syntax Check
```bash
bash -n line_wine_install_refactored.sh
# Expected: No output (success)
```

### Dry Run (shows what would happen)
```bash
bash -x line_wine_install_refactored.sh 2>&1 | head -100
```

### Full Test Run
```bash
# Test on a test distro/VM first (not production)
./line_wine_install_refactored.sh
# Navigate menu, test each option
```

---

## Backward Compatibility

- **Original script still works**: `line_wine_install.sh` unchanged
- **No breaking changes**: Same options, better UX
- **Gradual migration**: Can keep both during transition
- **Data persistence**: Wine prefix/settings transferred automatically

---

## Performance Comparison

| Operation | Original | Refactored | Improvement |
|-----------|----------|-----------|-------------|
| Menu selection | Manual read + echo | gum choose | ✅ Better UX |
| Long operations | No feedback | Spinner + progress | ✅ User clarity |
| Error handling | Basic (`set -e`) | Trap + structured logging | ✅ Debuggable |
| Path detection | Hardcoded (1 path) | Auto-search (5+ paths) | ✅ Robust |
| CRYPT32 issue | Manual workaround | Menu option | ✅ Discoverable |
| Color changes | Edit 20+ lines | Edit CONFIG section | ✅ Maintainable |

---

## Troubleshooting

### Issue: "gum not found"
```bash
# Install gum (via Nix if home-manager managed)
nix-shell -p gum
# Or: sudo dnf install gum / sudo apt install gum
```

### Issue: "Wine not found"
```bash
# Script will prompt to install via menu option 1
# Or manually: sudo dnf install wine
```

### Issue: "LINE launcher not found"
```bash
# Script auto-detects. If still fails:
find ~/.wineprefixes/line/drive_c -name "LineLauncher.exe" -o -name "line.exe"
# Then add path to launcher_paths array in find_line_launcher()
```

### Issue: "CRYPT32.dll NO_SIGNATURE"
```bash
# Use menu option 4: "🔧 Fix CRYPT32 Signature Issue"
# Or manually: See LINE_TROUBLESHOOTING.md (Solution 1, 2, or 3)
```

---

## Files Generated/Modified

```
~/.config/home-manager/distro/fedora/package/line/
├── line_wine_install_refactored.sh      ← New (refactored, production)
├── line_wine_install.sh                 ← Original (unchanged, for reference)
├── line_wine_install.sh.bak             ← Backup from prior fix
├── REFACTORING_GUIDE.md                 ← Architecture documentation
├── GUM_BASH_QUICK_REF.md                ← Pattern reference
├── LINE_TROUBLESHOOTING.md              ← Three-layer diagnostic guide
├── FIX_SUMMARY.md                       ← Prior fixes applied
└── DEPLOYMENT.md                        ← This file
```

---

## Future Enhancements

Potential improvements for future versions:

1. **Proton Alternative**: Add option to use Steam Proton instead of Wine
2. **Waydroid Support**: Detect and offer Waydroid (Android emulator) option
3. **Auto-Update**: Background task to check LINE updates
4. **Multi-Prefix**: Support multiple Wine prefixes for different LINE accounts
5. **Backup/Restore**: Automated backup of Wine prefix and settings
6. **Remote Launch**: Start LINE from command line with custom parameters
7. **Health Check**: Verify Wine installation, dependencies, disk space before starting

---

## Support & References

### Documentation
- **Gum-Bash Design System**: `GUM_BASH_QUICK_REF.md`
- **LINE Troubleshooting**: `LINE_TROUBLESHOOTING.md`
- **Refactoring Details**: `REFACTORING_GUIDE.md`
- **Prior Fixes**: `FIX_SUMMARY.md`

### Community
- **WineHQ AppDB** (LINE): https://appdb.winehq.org/objectManager.php?sClass=application&iId=20933
- **Wine Wiki**: https://wiki.winehq.org/
- **Charmbracelet Gum**: https://github.com/charmbracelet/gum

### Related Tools
- **Gum CLI**: Terminal UI toolkit (spinners, colors, prompts)
- **Winetricks**: Automated Wine configuration utility
- **Proton**: Steam's compatibility layer (Wine fork for gaming)
- **Waydroid**: Android emulator (alternative to Wine for LINE)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-06-03 | Initial gum-bash refactoring, Layer 1-3 fixes |

---

## Credits

- **Original Script**: LINE installation guide (various sources)
- **Gum-Bash Design**: Charmbracelet gum CLI + design patterns
- **Refactoring & Fixes**: Recent debugging sessions addressing gum flag parsing, WINEDEBUG, path detection, CRYPT32 signature issues

---

## License

[Same as parent repository — adjust based on your setup]

---

**Questions?** See the troubleshooting guides or consult WineHQ AppDB community.
