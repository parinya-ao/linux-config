# 🐧 linux-config: Universal Nix/Home Manager Bootstrap

This repository provides a declarative, cross-distribution development environment using **Nix Flakes** and **Home Manager**. It automates the transition from a fresh Linux installation to a fully-equipped workstation in minutes.

## 🏗️ Architecture & Core Technologies

- **Nix Flakes**: Manages reproducible dependencies and system state.
- **Home Manager**: Manages user-specific configurations, dotfiles, and packages.
- **Bootstrap Engine**: `startup.sh` detects the distribution and dispatches to specific drivers in `distro/` (Ubuntu/Debian, Fedora, openSUSE).
- **Module System**: Configurations are split into `modules/packages` (what to install) and `modules/programs` (how to configure).
- **Suites**: High-level toggles in `home.nix` (Base, Development, AI, Desktop) for rapid personality switching.

## 🚀 Key Commands

### Initial Setup
```bash
# Automated bootstrap (Installs Nix, HM, and applies config)
bash startup.sh
```

### Daily Operations
```bash
# Apply configuration changes
home-manager switch --flake ~/.config/home-manager

# Update all packages (updates flake.lock)
nix flake update && home-manager switch --flake ~/.config/home-manager

# Clean up old generations to save space
nix-collect-garbage -d
```

### Development & Maintenance
```bash
# Format Nix files
nix fmt

# List previous environment generations
home-manager generations
```

## 📂 Project Structure

- `flake.nix`: The entry point for the Nix configuration.
- `home.nix`: Primary user configuration; defines active suites.
- `modules/`:
    - `suites.nix`: Defines the `my.suites` options.
    - `packages/`: Nix package lists (cli, dev, ai, gui, docs).
    - `programs/`: Deep configuration for Bash, Fish, Git, GNOME, Neovim, etc.
- `distro/`: Distribution-specific setup scripts (driver layer).
- `steps/`: Individual bootstrap stages (init, nix install, hm setup).

## 🛠️ Development Conventions

- **Modular Design**: Avoid adding everything to `home.nix`. Create or update specific modules in `modules/packages` or `modules/programs`.
- **Suite-Based Configuration**: New features should generally be wrapped in a suite or a module option (e.g., `my.programs.X.enable`).
- **Universal Shell**: While Bash is configured, **Fish** is the intended interactive shell, pre-configured with Starship and modern Rust-based CLI tools (`eza`, `bat`, `fd`, `ripgrep`).
- **Username Constraint**: By default, this configuration expects the username `parinya`.

## 🤖 AI Features
This project includes a dedicated `ai` suite (`modules/packages/ai.nix`) and integrates tools like Claude Code and Claude Desktop via Nix Flakes.
