# CLAUDE.md — Agent Onboarding

## 📋 Project Overview
`linux-config` is a declarative, cross-distribution Linux environment manager using **Nix Flakes** and **Home Manager**. It automates system setup from a fresh install to a fully configured dev environment.

## 🚀 Key Commands
- **Apply Config:** `home-manager switch --flake .#parinya`
- **Update Dependencies:** `nix flake update`
- **Format Nix Code:** `nix fmt`
- **Bootstrap System:** `bash startup.sh`
- **Check Generations:** `home-manager generations`
- **Rollback:** `home-manager switch --flake . --switch-generation <N>`

## 🛠 Development Patterns
- **User Identity:** Defaults to `parinya`.
- **Modular Config:** 
    - Package lists go in `modules/packages/*.nix`.
    - Tool configs go in `modules/programs/*.nix`.
    - High-level toggles are managed via `my.suites` in `home.nix`.
- **Shells:** 
    - `startup.sh` and `distro/` use **Bash** (imperative).
    - Interactive environment is **Fish** (declarative config in `modules/programs/fish.nix`).

## 📚 Progressive Disclosure
For deeper technical understanding, read these files:
- `ARCHITECTURE.md`: High-level system design and file mapping.
- `GEMINI.md`: Comprehensive instructional context for AI agents.
- `QUICK_REFERENCE.md`: Troubleshooting and common command lists.
- `modules/suites.nix`: Logic for the suite-based configuration system.
