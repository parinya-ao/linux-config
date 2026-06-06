# ARCHITECTURE.md — linux-config System Design

> This document provides a comprehensive understanding of the linux-config codebase's architecture, enabling efficient navigation and effective contribution from day one. It is a living document—update as the system evolves.

## 1. Project Structure

```
/home/parinya/.config/home-manager/
├── .github/
│   └── workflows/ci.yaml          # CI/CD validation (fmt, lint, dead code, flake check)
├── flake.nix                       # Nix Flakes entry point; declares inputs, outputs
├── home.nix                        # Primary user configuration; suite toggles
├── startup.sh                      # Bootstrap entry point; detects distro, runs setup
├── modules/
│   ├── suites.nix                  # Defines my.suites options (Base, Dev, AI, Desktop)
│   ├── packages/                   # Package lists by category
│   │   ├── cli.nix                 # CLI tools (ripgrep, fd, bat, fzf, eza, etc.)
│   │   ├── dev.nix                 # Languages (rust, go, python, nix, nodejs, etc.)
│   │   ├── ai.nix                  # AI tools (Claude Code, Codex, RTK)
│   │   ├── gui.nix                 # GUI apps (GNOME, Firefox, etc.)
│   │   └── docs.nix                # Documentation tools
│   └── programs/                   # Deep tool configuration
│       ├── bash.nix                # Bash shell environment
│       ├── fish.nix                # Fish shell (primary interactive)
│       ├── git.nix                 # Git client & configuration
│       ├── starship.nix            # Starship prompt
│       ├── neovim.nix              # Neovim editor
│       ├── alacritty.nix           # Terminal emulator
│       ├── gnome.nix               # GNOME desktop settings
│       ├── agent-skills.nix        # Agent skills deployment
│       └── default.nix             # Module imports
├── distro/                         # Distribution-specific bootstrap drivers
│   ├── ubuntu/ubuntu.sh            # Ubuntu/Debian bootstrap
│   ├── fedora/fedora.sh            # Fedora/RHEL bootstrap
│   └── opensuse/opensuse.sh        # openSUSE/SLE bootstrap (with host/ subdirs)
├── steps/                          # Granular bootstrap stages
│   ├── init.sh, nix-install.sh, hm-setup.sh, hm-apply.sh
├── pkgs/                           # Custom Nix packages & derivations
│   └── agent-skills/               # **Centralized agent skill sources**
│       ├── default.nix             # Nix derivation (auto-discovers)
│       ├── <skill-name>/SKILL.md   # Skill files
│       └── install.sh              # Deployment script
├── docs/
│   ├── README.md                   # Project overview
│   ├── QUICK_REFERENCE.md          # Troubleshooting
│   └── CONTRIBUTING.md             # Contributing (if present)
├── .gitignore
└── flake.lock                      # Pinned dependency versions
```

## 2. High-Level System Diagram

The system operates in two distinct phases: **Bootstrap** (Imperative/Bash) and **Configuration** (Declarative/Nix).

```
┌─────────────────────────────────────────────────────────────────┐
│                    Fresh Linux Installation                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    bash startup.sh
                             │
        ┌────────────┬────────┴────────┬─────────────┐
        ▼            ▼                  ▼             ▼
    Ubuntu/Debian  Fedora/RHEL    openSUSE/SLE   Unsupported
   (ubuntu.sh)    (fedora.sh)     (opensuse.sh)   (error)
        │            │                  │
        └────────────┴──────────────────┘
                     │
        1. Nix installation (Determinate Systems)
        2. Distribution-specific setup (repos, drivers, snapper)
        3. Home Manager installation
        4. Flake-based configuration application
                     │
        ┌────────────┴────────────────────┐
        ▼                                  ▼
   flake.nix (entry point)         home.nix (user config)
        │                                  │
   [declarative inputs]             Enables suites:
   - nixpkgs                         - my.suites.base
   - home-manager                    - my.suites.development
   - flake-utils                     - my.suites.ai
   - custom overlays                 - my.suites.desktop
        │                                  │
        └────────────┬─────────────────────┘
                     │
        ┌────────────┴────────────┬──────────────────┐
        ▼                         ▼                  ▼
   modules/packages/         modules/programs/  modules/suites.nix
   (what to install)         (how to configure) (feature toggles)
        │
   - cli.nix              - bash.nix
   - dev.nix              - fish.nix
   - ai.nix               - git.nix
   - gui.nix              - neovim.nix
   - docs.nix             - starship.nix
                          - agent-skills.nix
                             & others
        │                         │
        └────────────┬────────────┘
                     │
            home-manager activate
                     │
    ┌─────────────────┼──────────────────┐
    ▼                 ▼                  ▼
Home dir config  ~/.config/*          Packages installed
(dotfiles)       (tool configs)       (.cache, .local)
```

## 3. Core Components

### 3.1. Nix Flakes (`flake.nix`)

**Name:** Declarative Dependency & System State Management

**Description:** 
Entry point for the entire configuration system. Declares all external dependencies (nixpkgs, home-manager), defines custom overlays, and produces the `homeConfigurations` output that Home Manager uses to build the user environment.

**Key Responsibilities:**
- Pin dependency versions (nixpkgs, home-manager, etc.) via flake.lock
- Define system-specific configurations (hostname, username)
- Configure Home Manager to use the local flake
- Provide custom Nix packages via overlays

**Technologies:** Nix, Nix Flakes

**Deployment:** Local machine; applied via `home-manager switch --flake .`

---

### 3.2. Home Manager Configuration (`home.nix`)

**Name:** User-Level Configuration & Dotfile Management

**Description:** 
Primary configuration file that enables/disables suites, defines user home directory structure, and orchestrates all installed packages and tool configurations. Serves as the single source of truth for the user's development environment.

**Key Responsibilities:**
- Enable/disable feature suites (Base, Development, AI, Desktop)
- Configure Home Manager modules (programs, packages, services)
- Set environment variables and shell aliases
- Manage dotfiles and configuration files

**Technologies:** Nix, Home Manager

**Deployment:** Applied via `home-manager switch --flake .`

---

### 3.3. Modular Configuration System

#### 3.3.1. Suites (`modules/suites.nix`)

**Name:** High-Level Feature Toggles

**Description:** 
Defines `my.suites` options that group related packages and configurations into logical bundles. Allows users to enable/disable entire feature sets without touching individual module files.

**Suites:**
- **Base**: Essential tools (git, shell, utils)
- **Development**: Programming languages, dev tools, editors
- **AI**: AI assistants (Claude, Codex)
- **Desktop**: GUI apps, desktop environment (GNOME, Firefox)

---

#### 3.3.2. Package Lists (`modules/packages/`)

**Name:** Declarative Package Installation

**Description:** 
Separate Nix modules for each category of packages. Each module defines a `my.packages.<category>.enable` option and the associated package list.

**Modules:**
- **cli.nix**: Command-line utilities (ripgrep, fd, bat, fzf, eza, jq, etc.)
- **dev.nix**: Programming languages and dev tools (Rust, Go, Python, Node.js, Nix, etc.)
- **ai.nix**: AI tools (Claude Code, Codex CLI, RTK)
- **gui.nix**: GUI applications (GNOME, Firefox, Thunderbird, etc.)
- **docs.nix**: Documentation tools

**Technologies:** Nix, nixpkgs

---

#### 3.3.3. Program Configurations (`modules/programs/`)

**Name:** Deep Tool Configuration

**Description:** 
Nix modules that configure individual tools declaratively. Each module defines a `my.programs.<tool>.enable` option and handles installation, configuration files, and environment setup.

**Key Modules:**
- **bash.nix**: Bash shell environment, .bashrc setup
- **fish.nix**: Fish shell config, abbreviations, functions (primary interactive shell)
- **git.nix**: Git client config, user info, aliases
- **starship.nix**: Starship prompt configuration
- **neovim.nix**: Neovim editor config, plugins, keybindings
- **alacritty.nix**: Terminal emulator config
- **gnome.nix**: GNOME desktop settings, keybindings, extensions
- **agent-skills.nix**: Deploys agent skills from `pkgs/agent-skills/`

**Technologies:** Nix, Home Manager, individual tool configuration formats

---

### 3.4. Bootstrap System

#### 3.4.1. Entry Point (`startup.sh`)

**Name:** Automated Bootstrap Orchestration

**Description:** 
Main entry point that detects the running Linux distribution and dispatches to the appropriate distro-specific bootstrap script.

**Workflow:**
1. Verify OS is Linux
2. Detect distribution (Ubuntu/Debian, Fedora/RHEL, openSUSE/SLE)
3. Dispatch to `distro/<distro>/<distro>.sh`
4. If distro not recognized, exit with error

**Technologies:** Bash

---

#### 3.4.2. Distribution-Specific Drivers (`distro/`)

**Name:** Cross-Distribution Bootstrap Support

**Description:** 
Each distribution has its own bootstrap driver that handles distro-specific package managers, repositories, and setup steps. Drivers normalize setup across different Linux distributions.

**Drivers:**

**Ubuntu/Debian (`distro/ubuntu/ubuntu.sh`)**
- Installs Nix (via Determinate Systems)
- Installs Home Manager
- Applies flake-based configuration

**Fedora/RHEL (`distro/fedora/fedora.sh`)**
- Installs Nix (via Determinate Systems)
- Handles SELinux considerations (if needed)
- Installs Home Manager
- Applies flake-based configuration

**openSUSE/SLE (`distro/opensuse/opensuse.sh`)**
- Installs Nix (via Determinate Systems)
- Configures Snapper (Btrfs snapshots for rollback)
- Sets up OBS repositories (if needed)
- Dispatches to modular `host/` scripts:
  - **snapper.sh**: Volume and snapshot management
  - **repos.sh**: Repository configuration
  - **drivers.sh**: Hardware driver setup
  - **docker.sh**: Docker & container setup
- Installs Home Manager
- Applies flake-based configuration

**Technologies:** Bash, distribution-specific package managers (apt, dnf, zypper)

---

#### 3.4.3. Bootstrap Stages (`steps/`)

**Name:** Sequential Setup Steps

**Description:** 
Individual scripts for discrete bootstrap phases. Can be run independently for testing or as part of the full workflow.

**Stages:**
- **init.sh**: Initial environment checks, prerequisite validation
- **nix-install.sh**: Nix installation (detects and uses appropriate method)
- **hm-setup.sh**: Home Manager installation and flake configuration
- **hm-apply.sh**: Initial configuration application

**Technologies:** Bash, Nix, Home Manager

---

### 3.5. Agent Skills (`pkgs/agent-skills/`)

**Name:** Centralized AI Agent Skill Management

**Description:** 
All agent skill source files (SKILL.md, references, scripts) are centralized in `pkgs/agent-skills/`. A Nix derivation auto-discovers all skill subdirectories and packages them for deployment.

**Architecture:**
```
pkgs/agent-skills/
├── default.nix            # Nix derivation (auto-discovers subdirs)
├── <skill-name>/
│   ├── SKILL.md           # Skill metadata & documentation
│   ├── references/        # Reference materials
│   └── scripts/           # Helper scripts
└── install.sh             # Deployment script
```

**Deployment:**
Via `home-manager switch`, skills are deployed to:
- `~/.config/opencode/skills/<skill-name>/`
- `~/.claude/skills/<skill-name>/`
- `~/.agents/skills/<skill-name>/`
- `~/.codex/skills/<skill-name>/`

**Technologies:** Nix, Bash

---

## 4. Data Stores & Configuration

### 4.1. Configuration Files

**Purpose:** Store user preferences, tool configurations, and environment settings

**Locations:**
- `~/.config/`: Primary config directory for most tools (git, fish, neovim, alacritty, etc.)
- `~/.bashrc`, `~/.bash_profile`: Bash initialization
- `~/.cache/`: Cached data (bat themes, ripgrep cache, etc.)
- `~/.local/`: Local user data and binaries

### 4.2. Flake Lock (`flake.lock`)

**Purpose:** Pin exact versions of all dependencies to ensure reproducibility

**Managed by:** `nix flake update` (updates all inputs to latest versions)

### 4.3. Nix Store (`/nix/store`)

**Type:** Content-addressable read-only filesystem

**Purpose:** Stores all packages and configuration files in isolation, preventing dependency conflicts

### 4.4. Home Manager Generations

**Type:** Symlink-based versioning

**Purpose:** Allows rollback of the entire environment to a previous known-good state via `home-manager switch --switch-generation <N>`

---

## 5. External Integrations

### 5.1. Package Repositories

**nixpkgs:** Primary package source; provides ~100,000 packages

**Inputs in flake.nix:**
```nix
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
```

### 5.2. Home Manager

**Purpose:** Declarative user-level configuration management on any Linux distribution

**Inputs in flake.nix:**
```nix
inputs.home-manager.url = "github:nix-community/home-manager/master";
```

### 5.3. Nix Flakes & Overlays

Custom Nix packages and agent skills can be added via flake inputs and overlays.

---

## 6. Deployment & Infrastructure

### 6.1. Target Environment

**Scope:** Individual user workstations (any Linux distribution)

**Supported Distributions:**
- Ubuntu, Debian, and derivatives
- Fedora, RHEL, CentOS, and derivatives
- openSUSE, SUSE Linux Enterprise

### 6.2. Installation & Application

**Initial Setup:**
```bash
bash startup.sh  # Auto-detects distro, installs Nix, HM, applies config
```

**Configuration Updates:**
```bash
home-manager switch --flake ~/.config/home-manager
```

**Dependency Updates:**
```bash
nix flake update && home-manager switch --flake ~/.config/home-manager
```

### 6.3. CI/CD Pipeline (`.github/workflows/ci.yaml`)

**Purpose:** Validate Nix code quality before merging

**Checks:**
1. **Format Check**: `nix fmt -- --ci` (Nix code formatting)
2. **Linting**: `statix check .` (Nix linter for best practices)
3. **Dead Code**: `deadnix -- --fail .` (Identifies unused code)
4. **Flake Validation**: `nix flake check --no-build` (Validates flake.nix syntax)
5. **Build Test**: `nix build` (Builds activationPackage without applying changes)

**Runs on:** Push to main branches, pull requests

---

## 7. Security Considerations

### 7.1. Bootstrapping Security

- **Determinate Systems Nix Installer**: Verifies checksums; safe for automatic installation
- **Home Manager Trust**: Uses standard Nix security model; code must be reviewed before applying

### 7.2. Secret Management

- **Secrets NOT stored** in configuration (no passwords, API keys, tokens)
- **Manual setup:** Environment variables for sensitive data set outside the flake
- **Future:** Consider sops-nix or agenix for encrypted secrets if needed

### 7.3. Code Integrity

- **Flake.lock**: Pins all dependencies; prevents supply chain attacks
- **CI validation**: Format, lint, and build checks before merge
- **Git history**: Track all configuration changes via commits

### 7.4. File Permissions

- Home Manager respects file permissions (e.g., ~/ is always 0700)
- Configuration files are readable only by the user

---

## 8. Development & Testing Environment

### 8.1. Local Development

**Prerequisites:**
- Linux system (Ubuntu, Fedora, openSUSE, or other supported distro)
- Bash shell (for bootstrap scripts)
- Git (to clone and contribute)

### 8.2. Testing & Validation

**Run before committing:**
```bash
nix fmt && git add .
statix check .
deadnix -- --fail .
nix flake check --no-build
```

**CI Automation:**
All checks run automatically in GitHub Actions on pull requests.

### 8.3. Code Quality Tools

- **nix fmt**: Formats Nix code consistently
- **statix**: Lint tool for Nix code
- **deadnix**: Identifies unused Nix code
- **nix flake check**: Validates flake.nix structure

---

## 9. Operational Management

### 9.1. Environment Management

**Apply Configuration:**
```bash
home-manager switch --flake ~/.config/home-manager
```

**Update Packages:**
```bash
nix flake update
home-manager switch --flake ~/.config/home-manager
```

**List Generations:**
```bash
home-manager generations
```

**Rollback to Previous Generation:**
```bash
home-manager switch --flake . --switch-generation <N>
```

### 9.2. Cleanup

**Remove Old Generations:**
```bash
nix-collect-garbage -d
```

---

## 10. Future Considerations & Roadmap

### 10.1. Known Architectural Debts

- **Distro Support**: Currently covers Ubuntu, Fedora, openSUSE; other distros require new drivers
- **Secrets Management**: No built-in encrypted secret storage; manual env var setup currently required
- **Dynamic Usernames**: Currently hardcoded to `parinya`

### 10.2. Planned Enhancements

- **Agent Skills Ecosystem**: Expand skill library; improve auto-discovery and deployment
- **Profile Management**: Support multiple configuration profiles (work, personal, minimal)
- **Offline Bootstrapping**: Reduce dependency on internet connectivity during setup
- **Performance Optimization**: Cache Nix builds to speed up repeated deployments
- **Secrets Integration**: sops-nix or agenix for encrypted secret storage

---

## 11. Project Identification

**Project Name:** linux-config

**Repository URL:** https://github.com/parinya-purnama/linux-config

**Primary Contact/Team:** Parinya (or community contributors)

**Date of Last Update:** 2026-06-06

---

## 12. Glossary / Acronyms

| Term/Acronym | Definition |
|--------------|-----------|
| **Nix** | Purely functional package manager and declarative OS configuration language |
| **Flakes** | Nix feature for composable, reproducible configurations with pinned dependencies |
| **Home Manager** | Tool for declarative user-level configuration and dotfile management on any Linux distro |
| **Flake.lock** | File that pins exact versions of all Nix dependencies for reproducibility |
| **Suite** | High-level feature toggle (Base, Development, AI, Desktop) that groups packages/configs |
| **Overlay** | Custom Nix package definitions or modifications to nixpkgs |
| **Module** | Reusable Nix configuration unit (e.g., `modules/programs/neovim.nix`) |
| **Derivation** | Nix term for a build recipe (e.g., how to build a package) |
| **Activation** | Process of applying Home Manager configuration to the user's home directory |
| **Generation** | Snapshot of a complete home environment; allows rollback |
| **CI/CD** | Continuous Integration/Continuous Deployment; automated testing & validation |
| **SELinux** | Security Enhanced Linux; mandatory access control system used by Fedora/RHEL |
| **Snapper** | Tool for managing Btrfs snapshots on openSUSE |
| **OBS** | Open Build Service; repository system for openSUSE packages |

---

## 13. Related Documents

- **CLAUDE.md**: Instructions for AI agents working with this codebase
- **QUICK_REFERENCE.md**: Troubleshooting guide and common commands
- **README.md**: Project overview and quick start
- **CONTRIBUTING.md**: Contributing guidelines (if present)
