# Linux Config 🐧

![Nix](https://img.shields.io/badge/Nix-5277C3?style=for-the-badge&logo=NixOS&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Fish Shell](https://img.shields.io/badge/Fish-Shell-4EAD3D?style=for-the-badge&logo=fish)
![GNOME](https://img.shields.io/badge/GNOME-Extensions-4A86E8?style=for-the-badge&logo=gnome&logoColor=white)

## Overview (View)
This project provides a universal bootstrap script and Home Manager configuration for Linux environments using Nix Flakes. It automatically detects your operating system and sets up a robust, declarative development environment. 

**Supported Distributions:**
* Ubuntu / Debian family (Pop!_OS, Linux Mint, Kali, etc.)
* Fedora
* openSUSE (Tumbleweed, Leap, Slowroll)

## Features
* **Nix & Home Manager Integration**: Fully automated installation of Nix via Determinate Systems and configuration application using Home Manager flakes for the user `parinya`.
* **Modern Shell Environment**: Defaults to Fish shell integrated with the Starship prompt, `zoxide` (smart cd), `fzf` (fuzzy finder), and `direnv`.
* **Rust-based CLI Replacements**: Pre-configures modern alternatives like `eza` (for `ls`), `bat` (for `cat`), `fd` (for `find`), `ripgrep` (for `grep`), `duf` (for `df`), `dust` (for `du`), `btm` (for `top`), and `procs` (for `ps`).
* **Git Enhancements**: Includes powerful Git aliases, `delta` for side-by-side syntax-highlighted diffs, and automatic rebasing settings.
* **GNOME Desktop Customization**: Declaratively installs and configures GNOME extensions like Blur my Shell, Dash to Dock, Vitals, Just Perfection, and PaperWM directly through Nix.

## How to Install

Follow these steps to bootstrap your Linux environment:

1. Clone this project:
   ```bash
   git clone [https://github.com/parinya-ao/linux-config.git](https://github.com/parinya-ao/linux-config.git)
