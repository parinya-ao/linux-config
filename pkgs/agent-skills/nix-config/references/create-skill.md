# Create a New Agent Skill — Step by Step

## Prerequisites

- Repo cloned at `~/.config/home-manager`
- You understand SKILL.md YAML frontmatter format

## Steps

### 1. Create Skill Directory

```bash
mkdir -p pkgs/agent-skills/my-new-skill/references
```

### 2. Write SKILL.md

```markdown
---
name: my-new-skill
description: |
  Short description that triggers this skill.
  Use this skill whenever the user...
---
```

- `name` must match directory name
- `description` is what opencode/Claude uses to decide when to auto-load
- Optional: `argument-hint`, `user-invocable`

### 3. Add Optional Content

```
pkgs/agent-skills/my-new-skill/
├── SKILL.md
├── references/           # Longer reference docs
│   └── detailed-guide.md
└── scripts/              # Helper scripts
    └── audit.sh
```

### 4. Register in 4 Places

**File 1 — Derivation** (`pkgs/agent-skills/default.nix`):
```
for dir in ... my-new-skill ...
```

**File 2 — HM Module** (`modules/programs/agent-skills.nix`):
```nix
allSkills = [ ... "my-new-skill" ... ];
```

**File 3 — Install Script** (`share/install-agent-skills.sh`):
```bash
ALL_SKILLS=( ... my-new-skill ... )
```

### 5. Deploy

```bash
git add .
home-manager switch --flake .#parinya
```
