---
name: gum-bash
description: >
  Design and write beautiful, modular, production-grade bash scripts using the `gum`
  CLI tool from Charmbracelet (Bubbles + Lip Gloss in the terminal). Use this skill
  whenever a user asks to write a shell script with terminal UI, wants to beautify or
  refactor an existing bash script, needs progress spinners, colored output, structured
  logging, interactive prompts, or summary boxes. Also trigger when the user says things
  like "make my script look nice", "add a UI to my bash script", "I want a progress bar",
  "format my shell output", "gum script", or "glamorous shell" — even without mentioning
  gum by name. This skill provides a complete design system: color tokens, 4-layer
  architecture, spinner conventions, open pipeline pattern, and automation-safe guards.
---

# Gum Bash Design System

`gum` is a composable CLI tool (think: CSS + layout + interaction, but in the terminal).
Every gum command is a standalone binary — pipe them, substitute them, chain them.
Your job is to produce scripts that feel polished, are easy to maintain, and run
completely non-interactively unless the user explicitly wants prompts.

See `references/gum-commands.md` for a full command reference with flags.

---

## Step 0 — Always Start with a Design Pass

Before writing any code, mentally (or visibly) map:
1. What are the stages/parts of this script?
2. Which stages are long-running? (→ need spinners)
3. What does the user need to see at the end? (→ summary box)
4. Should it be interactive or fully automated?

---

## Step 1 — Config Block (Top of Every Script)

Always open with this block, right after `set -Eeuo pipefail`. Colors go here as
`readonly` constants — **never hardcode hex values inside functions**.

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
# Semantic color tokens — change theme here, nowhere else
readonly C_PRIMARY="#00BFFF"    # Deep Sky Blue  — headers, step indicators
readonly C_SUCCESS="#04B575"    # Mint Green     — ok, done, verified
readonly C_WARNING="#FFA500"    # Amber          — advisory, skipped steps
readonly C_DANGER="#FF4500"     # Red-Orange     — errors, abort
readonly C_MUTED="#666666"      # Dim Gray       — secondary text, labels
readonly C_ACCENT="#C678DD"     # Soft Purple    — version numbers, paths
readonly C_HIGHLIGHT="#98C379"  # Soft Green     — filenames, commands

# Gum defaults — override per-call with --flag if needed
export GUM_SPIN_SPINNER="line"
export GUM_LOG_LEVEL="info"
export GUM_LOG_TIME="rfc822"
```

---

## Step 2 — Layer 1: UI Primitives

These functions are **pure formatting — zero logic**. They take text, return styled output.
Write them early, use them everywhere.

```bash
# ── LAYER 1: UI PRIMITIVES ──────────────────────────────────────────────────

banner() {
  # Full-width header splash. Use once at script start.
  gum style \
    --border double --border-foreground "$C_PRIMARY" \
    --align center --padding "1 4" --bold \
    "$*"
}

step() {
  # Announce the start of a numbered stage.
  # Usage: step 2 "Installing Nix"
  gum style --foreground "$C_PRIMARY" --bold "▶  Step ${1}: ${2}"
}

ok() {
  gum style --foreground "$C_SUCCESS" "  ✔  $*"
}

warn() {
  gum style --foreground "$C_WARNING" "  ⚠  $*"
}

fail() {
  # Print error box then exit. Use for unrecoverable failures.
  gum style \
    --border thick --border-foreground "$C_DANGER" \
    --foreground "$C_DANGER" --bold \
    --padding "0 2" \
    "✖  ERROR: $*"
  exit 1
}

info() {
  gum style --foreground "$C_MUTED" "  ℹ  $*"
}

kv() {
  # Key-value row, label left-padded to fixed width for alignment.
  # Usage: kv "OS" "Ubuntu 24.04"
  local label value
  label=$(gum style --foreground "$C_MUTED"   --width 14 "$1")
  value=$(gum style --foreground "$C_ACCENT"           "$2")
  gum join --horizontal "$label" "$value"
}
```

---

## Step 3 — Spinner Wrapper

Create one `run_step` helper. Every long-running command goes through it —
this keeps stdout clean and gives every operation the same visual treatment.

```bash
# ── LAYER 2: RUNNER HELPER ──────────────────────────────────────────────────

run_step() {
  # Usage: run_step <spinner> "Human title" command [args...]
  # Exit contract: propagates command exit code.
  local spinner="$1" title="$2"
  shift 2
  if gum spin --spinner "$spinner" --title "  ${title}..." -- "$@"; then
    ok "$title"
  else
    local code=$?
    fail "$title (exit $code)"
  fi
}
```

**Spinner → Operation mapping** (pick the one that feels right for the task):

| Spinner   | Use for                              |
|-----------|--------------------------------------|
| `line`    | Package installs, apt/dnf/brew       |
| `dot`     | File processing, compilation         |
| `jump`    | git clone, network fetch             |
| `pulse`   | Health checks, connectivity tests    |
| `points`  | Nix store, database operations       |
| `globe`   | curl downloads, internet operations  |
| `moon`    | Long builds, overnight tasks         |
| `monkey`  | Cleanup, garbage collection          |
| `meter`   | Progress-like operations             |

Only wrap commands in `run_step` when they take more than ~1 second. For quick reads
(`/proc/stat`, `df`, `git status`) just call the command inline — a spinner that
flashes off instantly creates noise, not polish.

---

## Step 4 — Layer 3: Task Functions

Each task function does **one thing**. It returns:
- `0` → success (pipeline continues)
- `1` → skipped / soft failure (pipeline warns and continues)
- `2` → fatal (pipeline aborts)

Pattern for a task function:

```bash
install_nix() {
  # Idempotent guard — check before acting, skip if already done
  if command -v nix >/dev/null 2>&1; then
    info "Nix already installed ($(nix --version)), skipping"
    return 0
  fi

  step 2 "Installing Nix"
  run_step globe "Fetching Nix installer" \
    curl -fsSL https://install.determinate.systems/nix -o /tmp/nix-installer

  run_step points "Running Nix installer" \
    bash /tmp/nix-installer install --no-confirm

  ok "Nix installed: $(nix --version)"
}
```

---

## Step 5 — Open Architecture: Pipeline in main()

The pipeline is just an array of function names. Adding a new stage = appending one
string. No existing logic changes.

Choose between two pipeline variants based on the script's purpose:
- **Fail-fast pipeline** (`PIPELINE`): stop on first failure. Use for install/setup scripts.
- **Aggregate pipeline** (`CHECKS`): run all, collect the worst exit code. Use for health checks and audits.

```bash
# ── LAYER 4: ORCHESTRATION ──────────────────────────────────────────────────

main() {
  banner "MY SETUP SCRIPT v1.0"

  local PIPELINE=(
    "check_dependencies"
    "install_tools"
    "configure_environment"
    "run_healthcheck"
  )

  local step_num=1
  for task in "${PIPELINE[@]}"; do
    step "$step_num" "$task"
    if ! "$task"; then
      warn "Task '${task}' did not complete cleanly — continuing"
    fi
    (( step_num++ ))
  done

  show_summary
}
```

**Aggregate variant** (health checks, audits — run everything, report overall status):

```bash
main() {
  local CHECKS=("check_cpu" "check_memory" "check_disk")
  local worst=0
  for check in "${CHECKS[@]}"; do
    set +e; "$check"; code=$?; set -e
    (( code > worst )) && worst=$code
  done
  # 0=ok 1=warning 2=critical
  show_summary "$worst"
  exit "$worst"
}

main "$@"
```

---

## Step 6 — Summary Box

The summary is the last thing the user sees — make it count.
Use `gum join` to build a two-column table, then wrap in a styled border.

Always double-quote styled blocks before passing to `gum join` — unquoted newlines
get stripped.

```bash
show_summary() {
  local os="${1:-unknown}" tool_ver="${2:-?}" repo="${3:-~}"

  local title
  title=$(gum style --foreground "$C_SUCCESS" --bold "🎉  ALL DONE")

  local r1 r2 r3
  r1=$(kv "OS"      "$os")
  r2=$(kv "Version" "$tool_ver")
  r3=$(kv "Repo"    "$repo")

  local hint
  hint=$(gum style --foreground "$C_WARNING" "  ⚠  Open a new terminal for PATH changes")

  local body
  body=$(gum join --vertical --align left \
    "$title" "" "$r1" "$r2" "$r3" "" "$hint")

  gum style \
    --border rounded --border-foreground "$C_SUCCESS" \
    --padding "1 3" \
    "$body"
}
```

---

## Step 7 — Automation-Safe Guards (Non-Interactive)

Three pillars — apply all three to every task function:

**Pillar 1 — Idempotent Guards**: check before executing.
```bash
[ -d "$HOME/.config/my-tool" ] && { info "Config exists, skipping setup"; return 0; }
```

**Pillar 2 — Cascading Fallback**: always have an alternative.
```bash
install_package() {
  dnf install -y "$1" 2>/dev/null \
  || apt-get install -y "$1" 2>/dev/null \
  || brew install "$1" 2>/dev/null \
  || warn "Could not install $1 — skipping"
}
```

**Pillar 3 — Trap-Based Error Recovery**: catch unexpected exits.
```bash
trap 'gum log --level error "Unexpected failure" line="$LINENO" exit="$?"' ERR
```

---

## Structured Logging with `gum log`

Replace all raw `echo`/`printf` with `gum log` for machine-readable, leveled output:

```bash
gum log --level info  "Task started"  stage="install" target="nix"
gum log --level warn  "Step skipped"  reason="already installed"
gum log --level error "Command failed" cmd="apt-get"  code="$?"
```

Levels: `debug` · `info` · `warn` · `error` · `fatal`
Key options: `--structured` (key=value pairs) · `--time rfc822` · `--prefix "STAGE"`

---

## Border Conventions

| Context                  | Border type | Color       |
|--------------------------|-------------|-------------|
| Script header splash     | `double`    | C_PRIMARY   |
| Section separators       | `normal`    | C_MUTED     |
| Info / tip boxes         | `rounded`   | C_WARNING   |
| Final success banner     | `rounded`   | C_SUCCESS   |
| Critical warnings        | `thick`     | C_WARNING   |
| Error box (before exit)  | `thick`     | C_DANGER    |

---

## Checklist Before Finishing

Before returning any script:
- [ ] `readonly` color constants at top, none in function bodies
- [ ] `set -Eeuo pipefail` present
- [ ] All long-running commands wrapped in `run_step`
- [ ] Every task function has an idempotent guard
- [ ] `main()` uses a PIPELINE array, not hardcoded calls
- [ ] `gum join` blocks always double-quoted
- [ ] `show_summary` called at end of `main()`
- [ ] `trap ERR` handler present
- [ ] `need_cmd gum` check near top of `main()`
