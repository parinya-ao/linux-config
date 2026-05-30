#!/usr/bin/env bash
# ===========================================================================
# install-agent-skills.sh — Install AI Agent Skills Globally
# ===========================================================================
#
# SYNOPSIS
#   ./install-agent-skills.sh [--user <user>]... [--all-users] [--system]
#                            [--dry-run] [--help]
#
# DESCRIPTION
#   Installs AI agent skill files (SKILL.md) from the Nix store into
#   agent skill directories for one or more users.  Skills become
#   available to OpenCode, Claude Code, Codex CLI, and any AI agent
#   that reads from ~/.config/opencode/skills/, ~/.claude/skills/,
#   ~/.agents/skills/, or ~/.codex/skills/.
#
#   The skills are packaged as a Nix derivation (pkgs/agent-skills)
#   which is built from the flake.  The resulting store path is
#   globally readable by every user on the system.
#
# OPTIONS
#   --user <user>     Install skills for <user> (repeatable).
#   --all-users       Install for every user under /home/ (quiet mode).
#   --system          Create a shared copy under /usr/local/share/agent-skills/.
#   --global-dir DIR  Central skill directory under $HOME (default: .local/share/agent-skills).
#                     All agents can reference a single shared location.
#   --dry-run         Show what would be done without making changes.
#   --help            Show this help text and exit.
#
# EXAMPLES
#   # Install for current user only
#   ./install-agent-skills.sh
#
#   # Install for two specific users
#   sudo ./install-agent-skills.sh --user alice --user bob
#
#   # Install for every human user on the system
#   sudo ./install-agent-skills.sh --all-users
#
#   # Create a system-wide shared copy
#   sudo ./install-agent-skills.sh --system
#
#   # Custom global dir for all agents to share
#   ./install-agent-skills.sh --global-dir .config/agent-skills
# ===========================================================================

set -Eeuo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
readonly SCRIPT_DIR
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly C_PRIMARY="#00BFFF"
readonly C_SUCCESS="#04B575"
readonly C_WARNING="#FFA500"
readonly C_DANGER="#FF4500"
readonly C_MUTED="#666666"
readonly C_ACCENT="#C678DD"

export GUM_SPIN_SPINNER="line"
export GUM_LOG_LEVEL="info"
export GUM_LOG_TIME="rfc822"

# Agent skill directories to populate (relative to $HOME)
readonly AGENT_DIRS=(
  ".config/opencode/skills"
  ".claude/skills"
  ".agents/skills"
  ".codex/skills"
)

# All 13 skill names built by pkgs/agent-skills
readonly ALL_SKILLS=(
  bash-defensive-patterns
  commit-context
  commit-history
  conventional-commit
  forget
  gum-bash
  handoff
  nix-backup
  react-doctor
  recall
  recap
  remember
  session-history
)

# ── STATE ───────────────────────────────────────────────────────────────────
DRY_RUN=false
declare -a TARGET_USERS=()
INSTALL_SYSTEM=false
GLOBAL_DIR=".local/share/agent-skills"

# ── UI PRIMITIVES (Gum-based, matching mcp.sh style) ────────────────────────

banner() {
  gum style --border double --border-foreground "$C_PRIMARY" --align center \
    --padding "1 4" --bold "$*"
}

step() {
  gum style --foreground "$C_PRIMARY" --bold "▶  Step ${1}: ${2}"
}

ok()   { gum style --foreground "$C_SUCCESS" "  ✔  $*"; }
warn() { gum style --foreground "$C_WARNING" "  ⚠  $*"; }
info() { gum style --foreground "$C_MUTED"   "  ℹ  $*"; }

fail() {
  gum style --border thick --border-foreground "$C_DANGER" \
    --foreground "$C_DANGER" --bold --padding "0 2" "✖  ERROR: $*"
  exit 1
}

kv() {
  local label="$1" value="$2"
  label=$(gum style --foreground "$C_MUTED"  --width 22 "$label")
  value=$(gum style --foreground "$C_ACCENT" "$value")
  gum join --horizontal "$label" "$value"
}

# ── HELP & ARGUMENT PARSING ─────────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install AI agent skills globally from the Nix store.

Options:
  --user <user>     Install for <user> (repeatable; default: current user)
  --all-users       Install for every user in /home/
  --system          Copy to /usr/local/share/agent-skills/ as well
  --global-dir DIR  Central skill dir under \$HOME (default: .local/share/agent-skills)
  --dry-run         Show what would be done without making changes
  -h, --help        Show this help message

Examples:
  $(basename "$0")
  sudo $(basename "$0") --user alice --user bob
  sudo $(basename "$0") --all-users
  sudo $(basename "$0") --system
  $(basename "$0") --global-dir .config/agent-skills
EOF
  exit "${1:-0}"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user)
        [[ -n "${2:-}" ]] || fail "--user requires a username"
        TARGET_USERS+=("$2")
        shift 2
        ;;
      --all-users)
        INSTALL_ALL_USERS=true
        shift
        ;;
      --system)
        INSTALL_SYSTEM=true
        shift
        ;;
      --global-dir)
        GLOBAL_DIR="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        usage 0
        ;;
      --)
        shift
        break
        ;;
      *)
        fail "Unknown option: $1 (use --help for usage)"
        ;;
    esac
  done
}

# ── DEPENDENCY CHECKS ───────────────────────────────────────────────────────

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Required command not found: $1"
  fi
}

check_deps() {
  local missing=0
  for cmd in gum nix; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "ERROR: Required command not found: $cmd" >&2
      missing=1
    fi
  done
  if [[ $missing -eq 1 ]]; then
    echo "  Install: nix — https://nixos.org/download/"
    echo "  Install: gum — https://github.com/charmbracelet/gum"
    exit 1
  fi
}

# ── CORE LOGIC ──────────────────────────────────────────────────────────────

# Build pkgs/agent-skills from the flake and return the store path.
build_skills_package() {
  local store_path

  step 1 "Building agent-skills package from flake"

  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY RUN] Would run: nix build --no-link --print-out-path \
  path:$REPO_ROOT#agent-skills"
    echo "/nix/store/dry-run-agent-skills"
    return 0
  fi

  store_path=$(nix build --no-link --print-out-path \
    "path:$REPO_ROOT#agent-skills" 2>/dev/null) || {
    store_path=$(nix build --no-link --print-out-path \
    "path:$REPO_ROOT#agent-skills" 2>&1) && fail "Build failed: $store_path"
  }

  ok "Built: $store_path"
  echo "$store_path"
}

# Install skills from a given store path into a user's home directory.
install_for_user() {
  local store_path="$1"
  local user="$2"
  local home_dir

  home_dir=$(getent passwd -- "$user" 2>/dev/null | cut -d: -f6) || {
    warn "User '$user' does not exist, skipping"
    return 1
  }

  if [[ ! -d "$home_dir" ]]; then
    warn "Home directory $home_dir for user '$user' not found, skipping"
    return 1
  fi

  info "Installing for user: $user ($home_dir)"

  local linked=0 skipped=0
  for skill in "${ALL_SKILLS[@]}"; do
    local skill_src="$store_path/$skill/SKILL.md"

    if [[ ! -f "$skill_src" ]]; then
      warn "SKILL.md not found in package: $skill (skipping)"
      continue
    fi

    for rel_dir in "${AGENT_DIRS[@]}"; do
      local target_dir="$home_dir/$rel_dir/$skill"
      local target_file="$target_dir/SKILL.md"

      if [[ -f "$target_file" ]]; then
        # Compare with store path — if already pointing there, skip
        if [[ "$(readlink -f "$target_file" 2>/dev/null || true)" == "$(readlink -f "$skill_src" 2>/dev/null || true)" ]]; then
          ((skipped++)) || true
          continue
        fi
        # Different file exists — warn and overwrite
        warn "Overwriting existing: $rel_dir/$skill/SKILL.md"
      fi

      if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] mkdir -p $target_dir && ln -sf $skill_src $target_file"
        ((linked++)) || true
        continue
      fi

      mkdir -p "$target_dir"
      ln -sf "$skill_src" "$target_file"
      ((linked++)) || true
    done
  done

  if [[ "$DRY_RUN" == false ]]; then
    ok "User '$user': $linked symlinks created, $skipped unchanged"
  else
    info "[DRY RUN] User '$user': $linked symlinks to create, $skipped unchanged"
  fi
}

# Install a central shared directory under $HOME (e.g. ~/.local/share/agent-skills/).
# All agents that support a SKILLS_DIR config can point here, avoiding N symlinks.
install_global_dir() {
  local store_path="$1"
  local rel_dir="${GLOBAL_DIR}"
  local abs_dir="$HOME/$rel_dir"

  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY RUN] Would create: $abs_dir (symlink to $store_path)"
    return 0
  fi

  if [[ -d "$abs_dir" ]]; then
    if [[ "$(readlink -f "$abs_dir" 2>/dev/null || true)" == "$(readlink -f "$store_path" 2>/dev/null || true)" ]]; then
      info "Global dir already up to date: $rel_dir"
      return 0
    fi
    warn "Recreating global dir: $rel_dir"
    rm -rf "$abs_dir"
  fi

  mkdir -p "$(dirname "$abs_dir")"
  ln -sf "$store_path" "$abs_dir"

  ok "Global skill directory: ~/$rel_dir → $store_path"
}

# Install a system-wide shared copy to /usr/local/share/agent-skills/
install_system_wide() {
  local store_path="$1"
  local sys_dir="/usr/local/share/agent-skills"

  step 3 "Installing system-wide copy to $sys_dir"

  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY RUN] Would create: $sys_dir (symlinks to $store_path)"
    return 0
  fi

  if [[ -d "$sys_dir" ]]; then
    info "System directory already exists, updating symlinks"
    rm -rf "$sys_dir"
  fi

  mkdir -p "$(dirname "$sys_dir")"
  ln -sf "$store_path" "$sys_dir"

  ok "System-wide skills: $sys_dir → $store_path"
  info "Add this to shell config to use system-wide skills:"
  echo "  export OPENCODE_SKILLS_DIR=$sys_dir"
}

# Resolve users to install for.
resolve_target_users() {
  if [[ ${#TARGET_USERS[@]} -gt 0 ]]; then
    printf '%s\n' "${TARGET_USERS[@]}"
  elif [[ "${INSTALL_ALL_USERS:-false}" == true ]]; then
    # Find all users with a home directory in /home/
    getent passwd | awk -F: '{ if ($6 ~ "^/home/") print $1 }' | sort -u
  else
    whoami
  fi
}

# ── SUMMARY ─────────────────────────────────────────────────────────────────

show_summary() {
  local store_path="$1"
  shift
  local -a installed_users=("$@")

  local title
  title=$(gum style --foreground "$C_SUCCESS" --bold "🎉  SKILL INSTALLATION COMPLETE")

  local rows=()
  rows+=("$(kv "Nix store path" "${store_path:-/nix/store/...}")")
  rows+=("$(kv "Skills packaged" "${#ALL_SKILLS[@]}")")
  rows+=("$(kv "Users installed" "${#installed_users[@]}")")
  rows+=("$(kv "Global dir" "${HOME}/${GLOBAL_DIR}")")
  rows+=("$(kv "System-wide" "${INSTALL_SYSTEM:-false}")")

  local body
  body=$(gum join --vertical --align left "$title" "" "${rows[@]}")

  gum style --border rounded --border-foreground "$C_SUCCESS" --padding "1 3" "$body"
}

# ── MAIN ────────────────────────────────────────────────────────────────────

main() {
  parse_args "$@"

  check_deps

  banner "AI Agent Skills — Global Installer"

  # Build the Nix package
  local store_path
  store_path=$(build_skills_package)

  # Install for each target user
  declare -a installed_users=()
  step 2 "Installing skills into user directories"

  while IFS= read -r user; do
    [[ -z "$user" ]] && continue
    if install_for_user "$store_path" "$user"; then
      installed_users+=("$user")
    fi
  done < <(resolve_target_users)

  # Optional central global directory under $HOME
  install_global_dir "$store_path"

  # Optional system-wide installation
  if [[ "${INSTALL_SYSTEM:-false}" == true ]]; then
    install_system_wide "$store_path"
  fi

  show_summary "$store_path" "${installed_users[@]}"
}

main "$@"
