# CLAUDE.md — Agent Onboarding

## 📋 Project Purpose (WHY)
`linux-config` is a declarative environment manager that automates the transition from a fresh Linux install to a fully configured workstation. It aims for **reproducibility** across distributions (Ubuntu, Fedora, openSUSE) using Nix.

## 🏗️ Tech Stack & Structure (WHAT)
- **Core:** Nix Flakes & Home Manager.
- **Entry Points:** `startup.sh` (Initial bootstrap), `home.nix` (User config).
- **Modules (`modules/`):**
    - `suites.nix`: High-level feature toggles (`my.suites.base`, `development`, `ai`, `desktop`).
    - `packages/`: Nix package lists categorized by purpose.
    - `programs/`: Tool-specific configurations (Fish, Git, Neovim, etc.).
- **Drivers (`distro/`):** Imperative Bash scripts for OS-specific preparation.

## 🚀 Working on the Project (HOW)

### Key Commands
- **Apply Changes:** `home-manager switch --flake .#parinya`
- **Update Dependencies:** `nix flake update`
- **Bootstrap System:** `bash startup.sh` (Use on new systems)

### Verification & Linting
- **Format Code:** `nix fmt` (Always run before committing).
- **Dry Run:** `home-manager build --flake .#parinya` (Verifies Nix syntax and evaluation).
- **Check State:** `home-manager generations`

### Development Patterns
- **User Identity:** Hardcoded to `parinya`.
- **Modular Edits:** Add packages to `modules/packages/` and configurations to `modules/programs/`.
- **Suite-First:** Favor enabling/disabling suites in `home.nix` rather than manual package additions.

## 📚 Progressive Disclosure
Refer to these files for specialized context:
- `ARCHITECTURE.md`: Deep dive into file mapping and system data flow.
- `GEMINI.md`: Detailed instructions for AI agents (strategic guidance).
- `modules/suites.nix`: Implementation logic for the suite system.
