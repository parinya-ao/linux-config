# 🟢 LINE Desktop Linux Installer (Wine 64-bit)

A production-grade, interactive `gum-bash` utility designed to install and configure **LINE Desktop** on Linux using a optimized 64-bit Wine environment. This script automates the complex setup required for a stable LINE experience, including Thai language support and keyboard input fixes.

## 🚀 Features

- **Professional UI**: Powered by `gum` for a sleek, interactive terminal experience with progress spinners and colored logging.
- **Automatic OS Detection**: Supports **Fedora** and **Debian/Ubuntu** out of the box with intelligent dependency management.
- **Optimized Wine Prefix**: 
  - Initializes a dedicated 64-bit prefix at `~/.wineprefixes/line`.
  - Sets the environment to Windows 10 (required for modern LINE versions).
- **Core Component Automation**: Automatically installs essential runtimes via `winetricks`:
  - `vcrun2022`: Visual C++ Runtimes for app stability.
  - `corefonts`: Basic Microsoft fonts.
  - `cjkfonts`: Full support for Chinese, Japanese, and Korean characters.
  - `openal`: Audio library for calls and notifications.
- **Thai Language & Input Fixes**:
  - **Double-Typing Mitigation**: Applies registry tweaks for keyboard debounce and uses `XMODIFIERS="@im=none"` in the launcher.
  - **Font Rendering**: Ensures proper rendering for Thai glyphs.
- **Automation Ready**: Supports a non-interactive mode for CI/CD or scripted deployments.
- **Structured Logging**: Persistent logs are stored in `~/.local/share/line-wine-install/` for easy troubleshooting.

## 📋 Prerequisites

- **gum**: The script requires [gum](https://github.com/charmbracelet/gum) to be installed on your system.
- **Internet Access**: Required to download the LINE installer and Wine components.

## 🛠️ Usage

### Interactive Mode (Recommended)
Simply run the script to access the menu-driven installer:
```bash
bash line_wine_install.sh
```

### Automated Mode
Use the `--auto` or `-y` flag to skip interactive prompts (useful for bootstrap scripts):
```bash
bash line_wine_install.sh --auto
```

### Uninstallation
The script includes a built-in uninstaller that safely removes the Wine prefix, the cached installer, and the desktop shortcut:
1. Run `bash line_wine_install.sh`
2. Select `🔴 Uninstall LINE` from the menu.

## 📂 Key Paths

| Component | Path |
|-----------|------|
| **Wine Prefix** | `~/.wineprefixes/line` |
| **Desktop Shortcut** | `~/.local/share/applications/line.desktop` |
| **Log Directory** | `~/.local/share/line-wine-install/` |
| **Installer Cache** | `/tmp/LineInst.exe` |

## 🔍 Troubleshooting

### Thai characters appearing as boxes
If Thai text does not render correctly, go to **LINE Settings > Basic** and change the font to **'Tahoma'** or any Thai-compatible font installed by the script.

### Double letters when typing
The script automatically sets `XMODIFIERS="@im=none"` in the `.desktop` shortcut to disable IMEs that cause double-typing in Wine. If you launch LINE manually from the terminal, ensure you use:
```bash
env WINEPREFIX="$HOME/.wineprefixes/line" XMODIFIERS="@im=none" wine ...
```

### Audio Issues
Ensure `openal` was installed correctly. You can check the logs in `~/.local/share/line-wine-install/` to verify the `winetricks` execution status.

## 📜 License
This script is provided as-is under the MIT License. Use it at your own risk.
