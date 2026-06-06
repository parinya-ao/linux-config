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
- **Agent Skills (Centralized in `pkgs/agent-skills/`):** 
    - All skill source files (SKILL.md, references/, scripts/) live in `pkgs/agent-skills/<name>/`.
    - Add a new skill: create dir there, then register in 3 places (derivation, HM module, install script).
    - The Nix derivation (`pkgs/agent-skills/default.nix`) auto-discovers all skill subdirs.
    - `home-manager switch` deploys them to `.config/opencode/skills/`, `.claude/skills/`, `.agents/skills/`, `.codex/skills/`.
    - Old `.agents/skills/` and `.claude/skills/` source dirs are gone — all source is now in `pkgs/agent-skills/`.
- **Shells:** 
    - `startup.sh` and `distro/` use **Bash** (imperative).
    - Interactive environment is **Fish** (declarative config in `modules/programs/fish.nix`).

## 📋 Code Style & Conventions

**Nix:**
- Prefix options with `my.` (e.g., `my.programs.neovim.enable`)
- Use `lib.mkDefault` for suite-wide toggles to allow override
- Each tool/package should have its own module file

**Bash:**
- Used in bootstrap (`startup.sh`, `distro/`, `steps/`)
- Use `set -e` at script start for error handling
- Modular structure: `distro/<name>/<name>.sh` dispatches to `host/` subdirectory

**Fish:**
- Primary interactive shell, configured via `modules/programs/fish.nix`
- Aliases and abbreviations defined via Home Manager
- Starship prompt configured in `modules/programs/starship.nix`

## 🧪 Testing & Validation

Run before committing:
```bash
nix fmt && git add .
statix check .
deadnix -- --fail .
nix flake check --no-build
```

CI pipeline runs: format check, linting, dead code detection, and flake validation (no system-specific builds).

## ⚠️ Common Gotchas

- **Username**: Config defaults to `parinya`; changing requires flake.nix edits
- **Flake.lock stale**: Run `nix flake update` if seeing "hash mismatch" errors
- **Generation tracking**: `home-manager generations` only shows successful activations; use git for history
- **Distro quirks**: openSUSE uses Btrfs + Snapper by default; bootstrap accommodates this

## 📚 Progressive Disclosure
For deeper technical understanding, read these files:
- `ARCHITECTURE.md`: High-level system design and file mapping.
- `GEMINI.md`: Comprehensive instructional context for AI agents.
- `QUICK_REFERENCE.md`: Troubleshooting and common command lists.
- `modules/suites.nix`: Logic for the suite-based configuration system.
