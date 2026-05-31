# Cross-Distro Bootstrap

## How It Works

`startup.sh` detects the OS via `/etc/os-release`, then dispatches to the correct
distro driver in `distro/`. Each driver is fully self-contained and idempotent.

## Flow

```
startup.sh
    ├─ /etc/os-release detection
    ├─ ubuntu.sh   → apt, ubuntu-drivers, PipeWire, NVIDIA
    ├─ fedora/     → dnf, RPM Fusion, kmod-nvidia
    └─ opensuse/   → zypper, Packman, NVIDIA G05
```

Each driver installs:
1. System packages and firmware
2. GPU drivers (auto-detect NVIDIA/Intel/AMD)
3. Codecs and media support
4. Nix (via Determinate Systems installer)
5. Clones/pulls the config repo
6. Runs `home-manager switch`

## Manual Setup (any distro)

```bash
# 1. Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install
source ~/.nix-profile/etc/profile.d/nix.sh

# 2. Clone config
git clone https://github.com/parinya-ao/linux-config.git ~/.config/home-manager

# 3. Apply
nix shell nixpkgs#home-manager -c home-manager switch \
  --flake ~/.config/home-manager#parinya
```

## Troubleshooting

| Issue | Fix |
|---|---|
| Nix not found after install | `source ~/.nix-profile/etc/profile.d/nix.sh` |
| home-manager command not found | `nix shell nixpkgs#home-manager -c ...` |
| Build fails on new distro | Check `distro/` driver exists; run `nix flake check` |
| GPU drivers not detected | Manually run appropriate driver script from `distro/` |
