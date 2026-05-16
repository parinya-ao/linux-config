# Architecture Overview
This document serves as a critical, living template designed to equip agents with a rapid and comprehensive understanding of the codebase's architecture, enabling efficient navigation and effective contribution from day one. Update this document as the codebase evolves.

## 1. Project Structure
This section provides a high-level overview of the project's directory and file structure, categorised by architectural layer or major functional area. It is essential for quickly navigating the codebase, locating relevant files, and understanding the overall organization and separation of concerns.

/home/parinya/.config/home-manager/
├── audit/                # Tetragon tracing policy + Vector pipeline templates
├── distro/               # Distribution-specific driver scripts (Imperative Layer)
│   ├── fedora/           # Fedora-specific setup and services
│   ├── opensuse/         # openSUSE driver + host modules (snapper/repos/drivers/docker)
│   └── ubuntu/           # Ubuntu/Debian family setup
├── modules/              # Nix/Home Manager modules (Declarative Layer)
│   ├── packages/         # Lists of Nix packages by category (ai, cli, dev, etc.)
│   ├── programs/         # Deep configuration for specific tools (fish, git, gnome, etc.)
│   ├── suites.nix        # High-level feature toggles (Base, Dev, AI, Desktop)
│   └── default.nix       # Module entry point importing all sub-modules
├── flatpak/              # Flatpak application management scripts
├── lib/                  # Shared shell utility functions for drivers
├── flake.nix             # Root Nix Flake definition (Dependencies & Outputs)
├── home.nix              # Primary Home Manager configuration (User settings & active suites)
├── startup.sh            # Main universal entry point for system bootstrapping
├── README.md             # User-facing project overview
├── GEMINI.md             # AI-specific instructional context
└── ARCHITECTURE.md       # This document

## 2. High-Level System Diagram
The system operates in two distinct phases: **Bootstrap** (Shell) and **Configuration** (Nix).

[Fresh OS] --> [startup.sh] --> [Distro Driver (distro/)] --> [Nix/HM Installation]
                                          |
                                          v
[Nix Store] <--- [home-manager switch] <--- [flake.nix / home.nix]
      |
      +--> [Symlinked Dotfiles in $HOME]
      +--> [User Binaries in PATH]

## 3. Core Components

### 3.1. Bootstrap Engine (Imperative Layer)

Name: Universal Bootstrap Engine

Description: Detects the host Linux distribution and prepares the environment for Nix. It handles root-level tasks like package manager updates, firmware installation, and the initial Nix/Home Manager installation. It bridges the gap between a vanilla OS and a Nix-enabled system.

Technologies: Bash, `curl`, `git`, `sudo`, Distribution-specific package managers (`dnf`, `zypper`, `apt`).

Deployment: Executed manually on a fresh OS install via `bash startup.sh`.

### 3.2. Declarative Environment (Declarative Layer)

Name: Home Manager Configuration

Description: Defines the end-state of the user's home directory. It manages package installation, shell configuration, GNOME extensions, and tool-specific settings (dotfiles). It ensures reproducibility across different machines.

Technologies: Nix (Flakes), Home Manager.

Deployment: Managed via `home-manager switch --flake .#parinya`.

## 4. Data Stores

### 4.1. Nix Store

Name: Nix Store

Type: Content-addressable read-only filesystem (`/nix/store`).

Purpose: Stores all packages and configuration files in isolation, preventing dependency conflicts and ensuring that the environment is immutable and reproducible.

Key Schemas/Collections: N/A (Filesystem-based)

### 4.2. HM Generations

Name: Home Manager Generations

Type: Symlink-based versioning.

Purpose: Allows the user to roll back the entire environment to a previous known-good state. Each "switch" creates a new generation.

## 5. External Integrations / APIs

Nixpkgs: The primary source for all software packages (Unstable branch).

Home Manager Flake: Provides the framework for declarative user environments.

Claude Flakes: Integrates `claude-code` and `claude-desktop` directly into the Nix environment via external flake inputs (`github:sadjow/claude-code-nix`, `github:aaddrick/claude-desktop-debian`).

## 6. Deployment & Infrastructure

Cloud Provider: N/A (Local Workstation/Personal Linux Desktop)

Key Services Used: Systemd (for user services), GNOME (for desktop environment management).

CI/CD Pipeline: Manual `nix flake update` and local verification. GitHub Actions and GitLab CI are used for linting and build verification.

Monitoring & Logging: `btm` (Bottom), `vitals` (GNOME Extension), and optional Tetragon+Vector audit pipeline configured via Nix.

## 7. Security Considerations

Authentication: Sudo is required only for the initial bootstrap phase. Subsequent configuration changes are performed by the user without root privileges.

Authorization: Nix ensures that system-wide packages and user-specific packages do not interfere.

Data Encryption: TLS is used for fetching packages from the Nix cache and GitHub.

Key Security Tools/Practices: Reproducibility ensures that the exact same code is running across environments.

## 8. Development & Testing Environment

Local Setup Instructions: `bash startup.sh` followed by `home-manager switch --flake .`.

Testing Frameworks: Shellcheck for driver scripts.

Code Quality Tools: `nixfmt` (configured via `nix fmt`) for Nix files.

## 9. Future Considerations / Roadmap

- Implementation of `sops-nix` or `age` for secret management.
- Supporting dynamic usernames (currently hardcoded to `parinya`).
- **Native Docker installation for each distribution (work in progress).**

## 10. Project Identification

Project Name: linux-config

Repository URL: https://github.com/parinya-ao/linux-config

Primary Contact/Team: parinya-ao

Date of Last Update: 2026-05-14

## 11. Glossary / Acronyms

Nix: A purely functional package manager.

Flake: A hermetic, reproducible Nix project format.

Home Manager (HM): A Nix-based system for managing user environments.

Generation: A specific versioned state of the user environment.
