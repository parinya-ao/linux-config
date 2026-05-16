# 🐧 GEMINI.md — Project Instructional Context

This file provides the primary instructional context for AI agents working on the `linux-config` project. It summarizes the architecture, core technologies, and development conventions to ensure consistent and high-quality contributions.

## 📋 Project Overview
`linux-config` is a declarative, cross-distribution bootstrap system for Linux workstations. It uses **Nix Flakes** and **Home Manager** to manage user environments reproducibly across Ubuntu, Fedora, and openSUSE.

- **Primary Goal:** Transform a fresh Linux install into a fully-equipped workstation in minutes.
- **Philosophy:** KISS (Keep It Simple, Stupid). Prefer clear, modular logic over complex abstractions.
- **Target User:** Hardcoded to `parinya` (home directory: `/home/parinya`).

## 🏗️ Architecture & Core Technologies

### 1. Imperative Layer (Bootstrap)
- **`startup.sh`**: The main entry point. It detects the OS, installs Nix/Home Manager, and dispatches to distribution-specific drivers.
- **`distro/`**: Contains OS-specific logic (e.g., `fedora/fedora.sh`, `opensuse/opensuse.sh`).
- **`lib/`**: Shared shell libraries.
    - `lib/ui.sh`: Standardized logging and UI helpers (`step`, `ok`, `warn`, `fail`).
    - `lib/privilege.sh`: Standardized privilege management (`as_root`, `as_user`).
    - `lib/fedora-common.sh`: Shared hardware/firmware logic for Fedora variants.

### 2. Declarative Layer (Configuration)
- **`flake.nix`**: Defines external dependencies (inputs) and outputs (Home Manager configuration).
- **`home.nix`**: The primary user-level configuration file where "Suites" are enabled.
- **`modules/`**:
    - `suites.nix`: High-level feature toggles (Base, Development, AI, Desktop, Audit).
    - `packages/`: Nix package lists categorized by purpose (cli, dev, ai, gui, docs).
    - `programs/`: Deep configuration for specific tools (Fish, Git, Neovim, GNOME, etc.).

## 🚀 Key Commands

### Initial Setup
```bash
# Automated bootstrap (Installs Nix, HM, and applies config)
bash startup.sh
```

### Daily Operations
```bash
# Apply configuration changes
home-manager switch --flake .

# Update all packages (updates flake.lock)
nix flake update && home-manager switch --flake .

# Clean up generations and optimize disk space
bash clean.sh
```

### Development & Maintenance
```bash
# Format Nix files
nix fmt

# Migration helper (Update + Format + Switch)
# Available as a fish function
migrate
```

## 🛠️ Development Conventions

### 1. Modular Design
- **Avoid Bloat:** Do not add everything to `home.nix`.
- **Packages:** Add new packages to the appropriate module in `modules/packages/`.
- **Configuration:** Put tool-specific settings in `modules/programs/`.
- **Suites:** New high-level features should be wrapped in a suite toggle in `modules/suites.nix`.

### 2. Shell Scripting Standards
- Always use `set -Eeuo pipefail`.
- Use the shared libraries in `lib/` for UI and privilege management.
- Prefer `as_root` from `lib/privilege.sh` over raw `sudo`.
- Ensure idempotency: Scripts should check if a change is already applied before executing.

### 3. Tooling Preferences
- **Interactive Shell:** Fish is the default, pre-configured with Starship and modern CLI tools.
- **Modern CLI:** Prefer Rust-based alternatives like `eza`, `bat`, `btm`, `zoxide`, and `fd`.
- **Desktop:** GNOME is the primary target, configured via `dconf` in `modules/programs/gnome.nix`.

## 🤖 AI Onboarding
Refer to **[AGENTS.md](./AGENTS.md)** for a condensed version of this context specifically optimized for rapid agent onboarding and command reference.
