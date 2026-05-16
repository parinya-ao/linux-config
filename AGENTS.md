# 🤖 AGENTS.md — AI Agent Guidance & Onboarding

This document provides specialized context for AI agents (Claude, Gemini, Copilot) working on the `linux-config` repository.

## 📋 Project Purpose
`linux-config` is a declarative environment manager that automates the transition from a fresh Linux install to a fully configured workstation. It aims for **reproducibility** across distributions (Ubuntu, Fedora, openSUSE) using Nix Flakes and Home Manager.

## 🏗️ Tech Stack & Structure
- **Core:** Nix Flakes & Home Manager.
- **Entry Points:** `startup.sh` (Initial bootstrap), `home.nix` (User config).
- **Modules (`modules/`):**
    - `suites.nix`: High-level feature toggles (`my.suites.base`, `development`, `ai`, `desktop`).
    - `packages/`: Nix package lists categorized by purpose.
    - `programs/`: Tool-specific configurations (Fish, Git, Neovim, etc.).
- **Drivers (`distro/`):** Imperative Bash scripts for OS-specific preparation.

## 🚀 Key Commands
- **Apply Changes:** `home-manager switch --flake .`
- **Update Dependencies:** `nix flake update`
- **Bootstrap System:** `bash startup.sh`
- **Format Code:** `nix fmt`
- **Clean Junk:** `bash clean.sh`

## 🛠️ Development Conventions
- **User Identity:** Hardcoded to `parinya`.
- **Modular Design:** Avoid adding everything to `home.nix`. Create or update specific modules in `modules/packages` or `modules/programs`.
- **Suite-First:** Favor enabling/disabling suites in `home.nix` rather than manual package additions.
- **Fish Shell:** Fish is the intended interactive shell, pre-configured with Starship and modern Rust-based CLI tools (`eza`, `bat`, `fd`, `ripgrep`).

## 📚 Further Reading
- **[ARCHITECTURE.md](./ARCHITECTURE.md)**: Deep dive into file mapping and system data flow.
- **[README.md](./README.md)**: General project overview and installation instructions.
