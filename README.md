# linux-config 🐧
> Universal Nix & Home Manager bootstrap for a reproducible Linux development environment.

## Description
Setting up a new Linux machine often involves hours of manual configuration, installing packages, and tweaking dotfiles. **linux-config** solves this by providing a declarative, cross-distribution bootstrap process. It ensures that your development environment is consistent, reproducible, and ready to use in under an hour, whether you are on Ubuntu, Fedora, or openSUSE.

## Badges
![Nix](https://img.shields.io/badge/Nix-5277C3?style=for-the-badge&logo=NixOS&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Fish Shell](https://img.shields.io/badge/Fish-Shell-4EAD3D?style=for-the-badge&logo=fish)
![GNOME](https://img.shields.io/badge/GNOME-Extensions-4A86E8?style=for-the-badge&logo=gnome&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Last Commit](https://img.shields.io/github/last-commit/parinya-ao/linux-config?style=flat-square)
![Repo Size](https://img.shields.io/github/repo-size/parinya-ao/linux-config?style=flat-square)

## ✨ Features
- **🤖 Nix & Home Manager**: Fully automated, declarative configuration using Nix Flakes.
- **🐚 Modern Shell**: Fish shell with Starship, `zoxide`, `fzf`, and `direnv`.
- **⚡ Rust-based CLI**: High-performance alternatives like `eza` (ls), `bat` (cat), and `ripgrep` (grep).
- **🔧 Git Power-User**: Pre-configured aliases and `delta` for beautiful diffs.
- **🎨 GNOME Desktop**: Declarative extensions (Blur my Shell, Dash to Dock, PaperWM).
- **📦 Multi-Distro**: Native support for Ubuntu/Debian, Fedora, and openSUSE.

<details>
<summary><b>Click to see the full list of installed tools</b></summary>

### Core & Dev
- **Languages**: Rust, Node.js, Python, Go
- **Editors**: Neovim, VS Code
- **Tools**: Git, Docker, sqlite, htop, jq, curl, wget

### Utilities
- **CLI**: fzf, ripgrep, fd, bat, eza, zoxide, direnv
- **System**: btm, duf, procs, ugrep, lsd, fastfetch, tldr, p7zip
</details>

## 🚀 Installation

### 1️⃣ Pre-requisites
- **Username:** You **must** use the username `parinya` during OS installation for the default configuration to work.
- **Supported OS:** Ubuntu 22.04+, Fedora 37+, or openSUSE Tumbleweed/Leap.

### 2️⃣ Bootstrap (Automated)
Run the following commands on your fresh installation:

```bash
# Clone repository
git clone https://github.com/parinya-ao/linux-config.git ~/.config/home-manager
cd ~/.config/home-manager

# Run bootstrap (installs Nix, Home Manager, all packages & configs)
bash startup.sh
```

### 3️⃣ Post-Installation
1. Set Fish as your default shell: `chsh -s $(which fish)`
2. Log out and log back in (or reboot).

## 🔄 Usage

### Apply Changes
After modifying files in `~/.config/home-manager/`:
```bash
home-manager switch --flake ~/.config/home-manager
```

### Update All Packages
```bash
cd ~/.config/home-manager
nix flake update
home-manager switch --flake ~/.config/home-manager
```

### Run Nix Audit Session (Tetragon + Vector)
```bash
# Optional: apply tracing policy in a Kubernetes/Tetragon environment
nix-audit-apply-policy

# Auto-audit Home Manager switch
nix-audit-session

# Or run any provisioning command with audit capture
nix-audit-session -- home-manager switch --flake ~/.config/home-manager
```

Audit logs are automatically compacted and rotated at 10MB in:
`~/.local/state/nix-audit/`

### Rollback
```bash
# List generations
home-manager generations
# Switch to generation N
home-manager switch --flake ~/.config/home-manager --switch-generation N
```

## 🔧 Configuration
The project is structured to be modular and easy to extend.

<details>
<summary><b>Project Structure</b></summary>

```
~/.config/home-manager/
├── flake.nix             # Nix flake definition
├── home.nix              # Main Home Manager entry point
├── distro/               # OS-specific drivers
└── modules/
    ├── packages/         # Package lists (cli, dev, gui, etc.)
    └── programs/         # Tool-specific configurations (fish, git, gnome)
```
</details>

- **Suites**: Toggle high-level feature sets (Base, Development, AI, Desktop) in `home.nix`.
- **Modules**: Deep-dive into `modules/programs/` to customize specific tool behaviors.

## 🤝 Contributing
This is a personal configuration tailored for my workflow, but feel free to fork it and adapt it to your needs! If you find a bug or have a suggestion for a modern CLI tool, feel free to open an issue or submit a PR.

## 📜 License
Distributed under the MIT License. See `LICENSE` for more information (Placeholder).

---
**Last Updated:** 2026-05-14
**Tested On:** Ubuntu 24.04 LTS, Fedora 41, openSUSE Tumbleweed
