# Linux Config 🐧

![Nix](https://img.shields.io/badge/Nix-5277C3?style=for-the-badge&logo=NixOS&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Fish Shell](https://img.shields.io/badge/Fish-Shell-4EAD3D?style=for-the-badge&logo=fish)
![GNOME](https://img.shields.io/badge/GNOME-Extensions-4A86E8?style=for-the-badge&logo=gnome&logoColor=white)

## 🎯 Quick Start

**⏱️ Time Required:** ~30-60 minutes from fresh Linux install to fully configured environment

**👤 Username:** Must be `parinya` during OS installation

**▶️ Get Started:** See [END_TO_END_SETUP.md](END_TO_END_SETUP.md) for complete step-by-step instructions

---

## Overview

This project provides a universal bootstrap script and Home Manager configuration for Linux environments using Nix Flakes. It automatically detects your operating system and sets up a robust, declarative development environment from scratch.

**Supported Distributions:**

- ✅ Ubuntu / Debian family (Pop!\_OS, Linux Mint, Kali, Elementary, Neon, Zorin, etc.)
- ✅ Fedora Workstation (37+)
- ✅ openSUSE (Tumbleweed, Leap 15.x, Slowroll)

## ✨ Features

- **🤖 Nix & Home Manager Integration**: Fully automated installation of Nix via Determinate Systems and declarative configuration using Home Manager flakes for reproducible environments.
- **🐚 Modern Shell Environment**: Fish shell with Starship prompt, `zoxide` (smart cd), `fzf` (fuzzy finder), and `direnv` for project-specific environments.
- **⚡ Rust-based CLI Tools**: Modern, faster alternatives: `eza` (ls), `bat` (cat), `fd` (find), `ripgrep` (grep), `duf` (df), `dust` (du), `btm` (top), `procs` (ps).
- **🔧 Git Enhancements**: Powerful aliases, `delta` for syntax-highlighted diffs, and automatic rebasing settings.
- **🎨 GNOME Desktop**: Declaratively configured extensions (Blur my Shell, Dash to Dock, Vitals, Just Perfection, PaperWM).
- **📦 Development Tools**: Rust, Node.js, Python, Go, Docker, etc. - all pre-configured and ready to use.

## 📚 Documentation

Start with the appropriate guide for your needs:

### 🚀 For First-Time Setup

→ **[END_TO_END_SETUP.md](END_TO_END_SETUP.md)** - Complete step-by-step guide from OS installation to ready-to-use system

### ⚡ For Quick Reference

→ \*\*[QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Checklists, common issues, and troubleshooting commands

### 🔧 For Advanced Users & Enhancements

→ **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** - Dynamic usernames, secret management, multi-profile setup, Flatpak integration

## 🚀 Installation

### 1️⃣ Install Linux OS (Manual)

Choose your distribution and install it with username **`parinya`** ⚠️

Supported:

- Ubuntu 22.04 LTS, 24.04 LTS, 24.10, 25.04+
- Fedora 37+
- openSUSE Tumbleweed, Leap 15.x

### 2️⃣ Clone & Bootstrap (Automated)

```bash
# Clone repository
git clone https://github.com/parinya-ao/linux-config.git ~/.config/home-manager
cd ~/.config/home-manager

# Run bootstrap (installs Nix, Home Manager, all packages & configs)
bash startup.sh
```

### 3️⃣ Post-Installation (Manual)

```bash
# Set Fish as default shell
chsh -s $(which fish)

# (Optional) Configure display scaling for HiDPI: Settings → Displays → Scale

# Reboot to finalize changes
sudo reboot
```

**That's it!** Your system is ready to use. See [END_TO_END_SETUP.md](END_TO_END_SETUP.md) for detailed instructions and [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for troubleshooting.

## 🔄 Daily Usage

### Apply Configuration Changes

After modifying any file in `~/.config/home-manager/`:

```bash
home-manager switch --flake ~/.config/home-manager
```

### Update All Packages

```bash
cd ~/.config/home-manager

# Update flake inputs
nix flake update

# Apply changes
home-manager switch --flake ~/.config/home-manager
```

### Roll Back to Previous Generation

```bash
# List generations
home-manager generations

# Switch to previous version (replace N)
home-manager switch --flake ~/.config/home-manager --switch-generation N
```

## 📁 Project Structure

```
~/.config/home-manager/
├── README.md                          # This file
├── END_TO_END_SETUP.md               # Complete setup guide ← Start here!
├── QUICK_REFERENCE.md                # Troubleshooting & quick commands
├── IMPLEMENTATION_GUIDE.md           # Advanced customizations
├── startup.sh                        # Main bootstrap script
├── flake.nix                         # Nix flake definition
├── home.nix                          # Home Manager configuration
├── distro/
│   ├── fedora/fedora.sh              # Fedora driver
│   ├── ubuntu/ubuntu.sh              # Ubuntu/Debian driver
│   └── opensuse/opensuse.sh          # openSUSE driver
└── modules/
    ├── packages/                     # Nix packages to install
    │   ├── cli.nix                   # CLI utilities
    │   ├── dev.nix                   # Development tools
    │   ├── docs.nix                  # Documentation
    │   └── gui.nix                   # GUI applications
    └── programs/                     # Program configurations
        ├── bash.nix
        ├── fish.nix
        ├── git.nix
        ├── gnome.nix
        └── cli-tools.nix
```

## ✅ What Gets Installed

### Core Tools

- **Nix & Home Manager** - Declarative package & configuration management
- **Fish Shell** - Modern, friendly shell with completions
- **Starship** - Fast, minimal, feature-rich prompt

### Development

- **Languages**: Rust (cargo), Node.js (npm), Python, Go
- **Editors**: Neovim, VS Code
- **Tools**: Git, Docker, sqlite

### Utilities

- **CLI**: fzf, ripgrep, fd, bat, eza, zoxide, direnv
- **System**: btm, duf, procs, ugrep

### Desktop (GNOME)

- **Extensions**: Blur my Shell, Dash to Dock, Vitals, Just Perfection, PaperWM
- **Themes & Icons**: Declaratively configured

See [modules/packages/](modules/packages/) and [modules/programs/](modules/programs/) for the complete list.

## 🐛 Issues?

1. **First check:** [QUICK_REFERENCE.md](QUICK_REFERENCE.md) has solutions for 90% of common issues
2. **Setup problems:** Review [END_TO_END_SETUP.md](END_TO_END_SETUP.md) Step-by-Step section
3. **Advanced help:** See [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for configuration details

## 🎯 Key Points

- ⚠️ **Username must be `parinya`** during OS installation
- ✅ **Fully automated** from fresh OS to ready-to-code (except 3 manual post-install steps)
- 🔄 **Declarative configuration** - version control your entire environment
- 📦 **Cross-distro** - same setup works on Ubuntu, Fedora, openSUSE
- 🚀 **Fast** - binary caches make subsequent updates quick

## 🚀 Next Steps

- ✨ **Try secret management:** [IMPLEMENTATION_GUIDE.md - Secret Management](IMPLEMENTATION_GUIDE.md#secret-management)
- 🔐 **Use dynamic usernames:** [IMPLEMENTATION_GUIDE.md - Dynamic Username](IMPLEMENTATION_GUIDE.md#dynamic-username-support)
- 📱 **Add Flatpak apps:** [IMPLEMENTATION_GUIDE.md - Flatpak Integration](IMPLEMENTATION_GUIDE.md#flatpak-integration)

---

**Last Updated:** 2026-05-04
**Tested On:** Ubuntu 24.04 LTS, Fedora 41, openSUSE Tumbleweed
