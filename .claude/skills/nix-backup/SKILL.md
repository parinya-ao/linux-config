---
name: nix-backup
description: >
  Backup, restore, and recover Nix-based systems using Home Manager and Nix Flakes.
  Use when the user asks to backup their Nix config, roll back a generation, recover
  from a broken home-manager switch, migrate configs to a new machine, or audit
  their Nix store. Covers Git-based backup, generation snapshots, flake.lock
  pinning, store GC, and bootstrap recovery.
---

# Nix Backup & Recovery

This repo **is the backup** — your Nix Flake is a declarative, version-controlled
snapshot of your entire environment. This skill covers how to use it for recovery,
rollback, and audit.

---

## Step 1 — Git-Based Backup (Primary)

The Nix Flake repo at `~/.config/home-manager/` is the single source of truth.
Every `home-manager switch` is reproducible from its contents + `flake.lock`.

```bash
# Daily snapshot — commit & push after every successful switch
cd ~/.config/home-manager
git add -A
git commit -m "chore: snapshot $(date +%Y-%m-%d)"
git push
```

**What to commit:**
- `flake.nix` + `flake.lock` — pin every input version
- `home.nix` — top-level suite toggles
- `modules/` — all Nix module definitions
- `.claude/skills/` — agent skills (these files)
- `startup.sh` + `steps/` — bootstrap pipeline
- `config.toml` — central config

**What NOT to commit** (add to `.gitignore`):
- `result/` — Nix build symlinks
- `repomix-output.*` — generated exports
- `flake.lock` exceptions — keep it committed! It's your pinning mechanism.

---

## Step 2 — Generation Management

Home Manager keeps a history of every `switch`. Use generations for rollback.

```bash
# List all generations
home-manager generations

# Rollback to a specific generation (N — generation number)
home-manager switch --flake . --switch-generation <N>

# Remove old generations to free space
home-manager expire-generations "-30 days"

# Check current generation path (symlink to active config)
readlink ~/.local/state/home-manager/generation
```

**Generation anatomy:**
```
~/.local/state/home-manager/
├── generations/
│   ├── 1 -> /nix/store/...-home-manager-generation  # initial
│   ├── 2 -> ...                                      # after first change
│   └── 3 -> ...                                      # current
└── home-manager.json                                 # metadata
```

---

## Step 3 — Flake Lock Management

`flake.lock` pins every input revision. Update or roll back individual inputs.

```bash
# Update ALL inputs to latest
nix flake update

# Update a single input
nix flake update home-manager

# Roll back a single input to a known-good revision
nix flake lock --update-input nixpkgs

# Pin all inputs to current — no changes until explicit update
nix flake lock

# Check what changed
nix flake diff
```

**Lock hygiene:**
- Commit `flake.lock` to every backup commit — never `.gitignore` it
- Before a risky update, commit the current lock:
  ```bash
  git commit -m "chore: checkpoint before nix flake update"
  ```
- After updating, test with `home-manager switch --flake .` before pushing

---

## Step 4 — Nix Store Maintenance

```bash
# Report store usage
nix store du --human-readable

# Find unused paths (dry-run GC)
nix store gc --print-dead

# Actual garbage collection
nix store gc

# Auto-GC with time limit (removes paths older than N days)
nix store gc --max-freed 10GB

# Full store optimization (dedup identical files)
nix store optimise
```

**Store safety rules:**
- Never manually delete from `/nix/store/` — always use `nix store gc`
- A generation keeps its entire closure alive — expire generations first
- GC roots: `home-manager generations`, `nix profile`, `/run/current-system`

---

## Step 5 — Full Machine Recovery

When setting up a fresh machine or recovering from disaster:

### A — Bootstrap from Scratch

```bash
# 1. Clone the repo
git clone <repo-url> ~/.config/home-manager
cd ~/.config/home-manager

# 2. Run the bootstrap (installs Nix + Home Manager + applies config)
bash startup.sh
```

### B — Manual Recovery (if bootstrap fails)

```bash
# 1. Install Nix (Determinate Systems installer — handles most edge cases)
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix | sh -s -- install --no-confirm

# 2. Source Nix environment
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 3. Clone config
git clone <repo-url> ~/.config/home-manager

# 4. Apply config
nix run home-manager/master -- switch --flake ~/.config/home-manager#parinya
```

### C — Rollback on Existing Machine

```bash
# If last switch broke something:
home-manager generations                        # list all
home-manager switch --flake . --switch-generation <N>  # go back

# Or pin to a specific commit (no undo needed — just checkout old config):
git log --oneline -20                           # find known-good commit
git checkout <known-good-hash>
home-manager switch --flake .#parinya
git checkout main                               # go back to latest
home-manager switch --flake .#parinya           # reapply latest
```

---

## Step 6 — Automation via CI (Optional)

Run nightly backups automatically with GitHub Actions:

```yaml
# .github/workflows/backup.yml
name: nix-backup
on:
  schedule:
    - cron: "0 6 * * *"  # daily at 06:00
  workflow_dispatch:

jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          nix flake check
          echo "flake.lock is valid"
```

---

## Step 7 — Pre-Upgrade Safety Checklist

Before running `nix flake update` or `home-manager switch` with risky changes:

- [ ] `git status` — working tree clean
- [ ] `git log --oneline -5` — know your current commit
- [ ] `nix flake check` — config is valid
- [ ] `home-manager generations | head -3` — know rollback targets
- [ ] `nix store gc --print-dead | wc -l` — know GC impact
- [ ] Backup plan: `git commit -m "checkpoint before update"`
