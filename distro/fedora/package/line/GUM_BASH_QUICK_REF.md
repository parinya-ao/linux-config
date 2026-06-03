# Gum-Bash Design System — Quick Reference

Applied to: `line_wine_install_refactored.sh`

---

## Color Tokens (CONFIG Section)

```bash
readonly C_PRIMARY="#00BFFF"      # Headers, step numbers
readonly C_SUCCESS="#04B575"      # ✔ ok messages
readonly C_WARNING="#FFA500"      # ⚠ cautions
readonly C_DANGER="#FF4500"       # ✖ errors
readonly C_MUTED="#666666"        # Secondary labels
readonly C_ACCENT="#C678DD"       # Values, paths
readonly C_HIGHLIGHT="#98C379"    # Filenames, commands
```

**Rule:** Never hardcode hex in functions. Always use a token.

---

## Layer 1: UI Primitives

**When to use:**
- `banner()` → Once at script start, full-width splash
- `step()` → Before each major stage ("Step 1: Installing Wine")
- `ok()` → Confirm completion of a sub-step
- `warn()` → Advisory (skip, already done, etc.)
- `fail()` → Fatal error, show and exit(1)
- `info()` → Verbose/debug info
- `kv()` → Key-value rows in summary tables
- `section_header()` → Visual break between sections

**Example:**
```bash
banner "LINE DESKTOP INSTALLER"
step 1 "Installing System Wine"
ok "Wine installed successfully"
info "Skipping because already installed"
kv "Wine Version" "$(wine --version)"
```

---

## Layer 2: Runner Helpers

### `run_step <spinner> "Title" <command> [args...]`

Wraps a command in a spinner, shows result.

```bash
# Simple command
run_step line "Installing Wine packages" dnf install -y wine

# Command with multiple args
run_step points "Installing runtimes" \
  bash -c "WINEPREFIX='$WINE_PREFIX_DIR' winetricks -q corefonts"

# Result: spinner animates, then "✔  Installing Wine packages"
```

### `run_sudo_step <spinner> "Title" <command> [args...]`

Same, but wraps in `sudo` automatically.

```bash
run_sudo_step line "Installing Wine packages" dnf install -y wine
# Internally: sudo dnf install -y wine
```

**Spinner choices for this script:**
- `line` → Package installs (dnf, apt)
- `dot` → File operations (mkdir, rm, download)
- `globe` → Network download
- `points` → Winetricks (store-like operations)
- `pulse` → Wine reboot/restart
- `monkey` → Cleanup (wineboot -k, rm -rf)

---

## Layer 3: Task Functions

**Contract:** Return 0 on success, 1 on soft fail, 2 on fatal.

**Pattern:**
```bash
my_task() {
  # 1. Idempotent guard — check before acting
  if [ -f "$TARGET_FILE" ]; then
    info "Already done, skipping"
    return 0
  fi

  # 2. Announce the stage
  step 1 "Doing the thing"

  # 3. Execute with runner helpers
  run_step spinner "Sub-step description" command arg1 arg2

  # 4. Confirm completion
  ok "Task completed"
}
```

**In this script:**
- `install_wine_dnf()` — Guard: check `wine --version` first
- `setup_wine_prefix()` — Guard: check if `$WINE_PREFIX_DIR` exists
- `download_line_installer()` — Guard: check if installer cached

---

## Layer 4: Orchestration

### Pipeline Pattern (Fail-Fast)

```bash
local PIPELINE=(
  "setup_wine_prefix"
  "install_wine_runtimes"
  "download_line_installer"
  "install_line"
)

local step_num=1
for task in "${PIPELINE[@]}"; do
  if ! "$task"; then
    warn "Task did not complete cleanly"
  fi
  (( step_num++ ))
done
```

### Menu Pattern (gum choose)

```bash
choice=$(gum choose \
  --header "Select operation:" \
  "📦 Install Wine" \
  "⚙️  Setup Prefix" \
  "▶️  Launch LINE" \
  "❌ Exit")

case "$choice" in
  "📦 Install Wine"*) menu_install ;;
  "⚙️  Setup Prefix"*) menu_full_setup ;;
  "▶️  Launch LINE"*) launch_line ;;
  "❌ Exit"*) exit 0 ;;
esac
```

**Note:** Use glob match `"*"` in case of prefix decorations.

---

## Error Handling

```bash
# At top of script, after set -Eeuo pipefail
trap 'gum log --level error "Script failed at line $LINENO"' ERR

# In task functions, for user-readable errors
if ! some_command; then
  fail "Detailed error message here"
fi
```

---

## Structured Logging

```bash
# Basic logging
gum log --level info "Task started" stage="wine-install"
gum log --level warn "Step skipped" reason="already-installed"
gum log --level error "Command failed" cmd="dnf" code="$?"

# With structured key=value pairs
gum log --level info "Setting up prefix" \
  version="$(wine --version)" \
  prefix="$WINE_PREFIX_DIR"
```

---

## Idempotent Guard Patterns

### Pattern A: Command Check
```bash
if command -v wine &>/dev/null; then
  info "Wine already installed, skipping"
  return 0
fi
```

### Pattern B: File/Directory Check
```bash
if [ -d "$WINE_PREFIX_DIR" ]; then
  info "Wine prefix exists, skipping creation"
  return 0
fi
```

### Pattern C: Version Check
```bash
local installed_ver
installed_ver=$(wine --version)
if [ "$installed_ver" == "$EXPECTED_VERSION" ]; then
  info "Correct version installed, skipping"
  return 0
fi
```

---

## Summary Box (Final Output)

```bash
show_summary() {
  local title
  title=$(gum style --foreground "$C_SUCCESS" --bold "🎉  COMPLETE")

  local r1 r2 r3
  r1=$(kv "Item 1" "Value 1")
  r2=$(kv "Item 2" "Value 2")
  r3=$(kv "Item 3" "Value 3")

  local body
  body=$(gum join --vertical --align left \
    "$title" "" "$r1" "$r2" "$r3")

  gum style \
    --border rounded --border-foreground "$C_SUCCESS" \
    --padding "1 3" \
    "$body"
}
```

**Critical:** Double-quote all styled blocks before `gum join` — unquoted newlines get stripped.

---

## Debugging

### Enable verbose command execution:
```bash
bash -x line_wine_install_refactored.sh
```

### Trace a specific function:
```bash
set -x
my_function
set +x
```

### Check gum availability:
```bash
command -v gum && echo "gum available" || echo "gum missing"
gum --version
```

### See all environment defaults:
```bash
echo "GUM_SPIN_SPINNER=$GUM_SPIN_SPINNER"
echo "GUM_LOG_LEVEL=$GUM_LOG_LEVEL"
echo "WINEDEBUG=$WINEDEBUG"
```

---

## Customization Checklist

Before releasing a script:

- [ ] Color tokens defined at top (CONFIG section)
- [ ] `set -Eeuo pipefail` present
- [ ] `trap ERR` handler present
- [ ] Long-running commands wrapped in `run_step`
- [ ] Every task function has idempotent guard
- [ ] Main orchestration in `main()` function
- [ ] Gum check: `command -v gum || fail "gum required"`
- [ ] Summary box uses double-quoted `gum join` blocks
- [ ] Meaningful spinner selected for each operation
- [ ] Structured logging via `gum log` where relevant

---

## Common Mistakes

❌ **Mistake:** Hardcoding colors in functions
```bash
ok() {
  echo -e "\033[0;32m✔ $*\033[0m"  # Bad!
}
```

✅ **Fix:** Use tokens from CONFIG
```bash
ok() {
  gum style --foreground "$C_SUCCESS" "  ✔  $*"
}
```

---

❌ **Mistake:** Forgetting idempotent guard
```bash
install_wine() {
  sudo dnf install -y wine  # Runs every time!
}
```

✅ **Fix:** Check before executing
```bash
install_wine() {
  if command -v wine &>/dev/null; then
    info "Wine already installed, skipping"
    return 0
  fi
  # ... proceed with install
}
```

---

❌ **Mistake:** Unquoted `gum join` blocks
```bash
body=$(gum join --vertical \
  "$title"  \
  "$r1"     \
  "$r2")    # Newlines get stripped! Result is one line.
```

✅ **Fix:** Always double-quote
```bash
local body
body=$(gum join --vertical --align left \
  "$title" "" "$r1" "$r2" "$r3")  # Correct
```

---

## Resources

- Full gum reference: See `references/gum-commands.md` in gum-bash skill
- Charmbracelet gum docs: https://github.com/charmbracelet/gum
- This script: `line_wine_install_refactored.sh`
- Architecture explanation: `REFACTORING_GUIDE.md`
