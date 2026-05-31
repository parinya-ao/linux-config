---
name: nix-config
description: |
  Nix-based declarative environment management using Home Manager and Flakes.
  Use this skill whenever the user asks about the project's Nix architecture,
  adding/removing packages or programs, creating a new agent skill, bootstrapping
  on a different OS, updating/rollback/troubleshooting Home Manager, or modifying
  flake inputs/overlays.
---

# Nix Config — linux-config Project

| Concern | Approach |
|---|---|
| Config language | Nix (Flakes) |
| User env manager | Home Manager |
| Bootstrap layer | Bash (startup.sh + distro/) |
| Package source | nixpkgs (nixos-unstable) |
| Module system | Nix module options + my.* namespace |
| Suite toggles | my.suites (base, development, ai, desktop) |
| Skill management | pkgs/agent-skills derivation |
| Code formatter | nixfmt-tree (via `nix fmt`) |

---

## Decision Tree

```
User request
    ├─ "how does project work?" ────────► Section A: Architecture
    ├─ "add/remove package" ────────────► Section B: Manage Packages
    ├─ "add/remove program config" ─────► Section C: Manage Programs
    ├─ "create new skill" ──────────────► Section D: Agent Skills
    ├─ "new machine/other OS" ──────────► Section E: Cross-Distro Bootstrap
    ├─ "update/rollback/broken" ────────► Section F: Day-to-Day Commands
    └─ "add flake input/overlay" ───────► Section G: Flake & Overlays
```

---

## Section A — Architecture

### A1. Two-Layer System

```
Fresh OS → startup.sh → distro/ubuntu.sh | fedora.sh | opensuse.sh
                            ↓
                    Nix + Home Manager installed
                            ↓
              home-manager switch --flake .#parinya
                            ↓
                All dotfiles + packages managed
```

### A2. File-to-Component Map

| File | Purpose |
|---|---|
| `flake.nix` | Root inputs, outputs, packages, checks, homeConfigurations |
| `home.nix` | User config, suites toggles |
| `modules/default.nix` | Module entry point |
| `modules/suites.nix` | High-level toggles: my.suites.* |
| `modules/packages/*.nix` | Package lists by category |
| `modules/programs/*.nix` | Deep tool config |
| `pkgs/agent-skills/default.nix` | Derivation packaging SKILL.md files |
| `pkgs/agent-skills/<name>/` | Central skill source files |
| `distro/` | Distro-specific Bash bootstrap drivers |
| `startup.sh` | Universal entry point |

### A3. Module Namespace (`my.*`)

```nix
options.my.suites = {
  base.enable = lib.mkEnableOption "Base CLI & Shell tools";
  development.enable = lib.mkEnableOption "Development tools";
  ai.enable = lib.mkEnableOption "AI Tools & CLIs";
  desktop.enable = lib.mkEnableOption "GNOME Desktop & GUI apps";
};

options.my.programs.fish = lib.mkEnableOption "Fish shell";
```

### A4. Suite Activation

```nix
my.programs = {
  fish = lib.mkIf cfg.base.enable { enable = true; };
  neovim = lib.mkIf cfg.development.enable { enable = true; };
  agent-skills = lib.mkIf cfg.ai.enable { enable = true; };
};
```

---

## Section B — Manage Packages

**Categories:** `modules/packages/{cli,dev,ai,gui,docs,font}.nix`

```nix
# Add package to modules/packages/cli.nix
config = lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    ripgrep
    fd
    your-new-pkg   # ← add here
  ];
};
```

Then: `home-manager switch --flake .#parinya`

**Remove:** delete the line and re-run. GC later: `nix-collect-garbage`

---

## Section C — Manage Programs

### Create a new program module

```nix
# modules/programs/example.nix
{ config, lib, pkgs, ... }:
let cfg = config.my.programs.example; in
{
  options.my.programs.example.enable = lib.mkEnableOption "Example";
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.example-tool ];
    home.file.".config/example/config.toml".source = ./example-config.toml;
  };
}
```

### Register it

1. Add to `modules/suites.nix`: `example = lib.mkIf cfg.development.enable { enable = true; };`
2. Add to `modules/default.nix`: `imports = [ ./programs/example.nix ];`

---

## Section D — Agent Skills

### Structure

```
pkgs/agent-skills/my-new-skill/
├── SKILL.md              ← Required
├── references/           ← Optional: deep-dive docs
└── scripts/              ← Optional: shell scripts
```

### Register a new skill (4 files)

**1. Place skill dir in `pkgs/agent-skills/<name>/SKILL.md`**

**2. Update derivation** (`pkgs/agent-skills/default.nix`):
```nix
for dir in \
  conventional-commit \
  my-new-skill        # ← add here
do
  if [ -d "$src/$dir" ]; then
    mkdir -p "$out/$dir"
    cp "$src/$dir/SKILL.md" "$out/$dir/SKILL.md"
  fi
done
```

**3. Update HM module** (`modules/programs/agent-skills.nix`):
```nix
allSkills = [
  "conventional-commit"
  "my-new-skill"                # ← add here
];
```

**4. Update install script** (`share/install-agent-skills.sh`):
```bash
ALL_SKILLS=(
  conventional-commit
  my-new-skill                  # ← add here
)
```

**5. Deploy:** `home-manager switch --flake .#parinya`

### Deployment Mapping

| Source | Deploy Targets |
|---|---|
| `pkgs/agent-skills/<name>/` | ~/.config/opencode/skills/ |
| | ~/.claude/skills/ |
| | ~/.agents/skills/ |
| | ~/.codex/skills/ |
| | ~/.local/share/agent-skills/ |

---

## Section E — Cross-Distro Bootstrap

### On a fresh OS

```bash
git clone https://github.com/parinya-ao/linux-config.git ~/.config/home-manager
cd ~/.config/home-manager
bash startup.sh    # auto-detects distro, installs Nix, runs home-manager
```

### Manual Nix install (any distro)

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install
source ~/.nix-profile/etc/profile.d/nix.sh
git clone https://github.com/parinya-ao/linux-config.git ~/.config/home-manager
nix shell nixpkgs#home-manager -c home-manager switch --flake ~/.config/home-manager#parinya
```

### Distro Drivers

| Distro | Script | Package Manager |
|---|---|---|
| Ubuntu/Debian | `distro/ubuntu/ubuntu.sh` | apt |
| Fedora | `distro/fedora/` | dnf |
| openSUSE | `distro/opensuse/` | zypper |

Each driver is self-contained, idempotent, 100% non-interactive, and uses the same UI helpers (`step`, `ok`, `warn`, `info`, `fail`).

---

## Section F — Day-to-Day Commands

| Action | Command |
|---|---|
| Apply config | `home-manager switch --flake .#parinya` |
| Build only | `home-manager build --flake .#parinya` |
| Check generations | `home-manager generations` |
| Rollback to gen N | `home-manager switch --flake . --switch-generation N` |
| Update all deps | `nix flake update` |
| Format Nix code | `nix fmt` |
| Run flake checks | `nix flake check` |
| Build skill pkg only | `nix build .#agent-skills` |
| Garbage collect | `nix-collect-garbage` |

### Update workflow

```bash
nix flake update                    # update flake.lock
home-manager switch --flake .#parinya  # apply
git add flake.lock && git commit -m "chore(deps): update flake inputs"
```

### Rollback

```bash
home-manager generations        # list
home-manager switch --flake . --switch-generation N  # rollback
```

### When `home-manager switch` fails

```bash
git stash                      # revert local changes
home-manager switch --flake .#parinya  # retry
# Or build-only first:
home-manager build --flake .#parinya
```

---

## Section G — Flake & Overlays

### Add a flake input

```nix
# flake.nix
inputs.my-new-flake.url = "github:user/repo";
extraSpecialArgs = { inherit inputs; };
```

Use in a module: `inputs.my-new-flake.packages.${system}.default`

### Add an overlay

```nix
# flake.nix — in let block
myOverlay = final: prev: {
  my-pkg = prev.callPackage ./pkgs/my-pkg { };
};

pkgs = import nixpkgs {
  inherit system;
  config = { allowUnfree = true; };
  overlays = [ agentSkillsOverlay myOverlay ];
};
```

### Expose a flake package

```nix
# flake.nix — in outputs
packages.${system} = {
  agent-skills = pkgs.agent-skills;
  my-pkg = pkgs.my-pkg;
};
```

Build: `nix build .#my-pkg`

---

## Quick Reference — Gotchas

| Situation | Wrong | Right |
|---|---|---|
| Add a skill | Only update `agent-skills.nix` | Update PKG derivation + HM module + install script |
| Add a package | Modify `home.nix` directly | Add to `modules/packages/<cat>.nix` |
| New program | Inline in `home.nix` | Create `modules/programs/<name>.nix`, register in suites |
| Apply without git add | `home-manager` works with dirty tree | `git add` first — flakes read from Git index |
| Rollback | Revert Git + reapply | `home-manager generations` + switch |
| Update deps | Manual flake.lock edit | `nix flake update` |

---

## References

- `references/architecture.md` — Module system, options, patterns deep dive
- `references/create-skill.md` — Step-by-step: create a new agent skill from scratch
- `references/cross-distro.md` — Cross-distro bootstrap guide with troubleshooting
- `scripts/verify-config.sh` — Validate skill lists are consistent
