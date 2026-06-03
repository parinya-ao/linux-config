#!/usr/bin/env bash
set -Eeuo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
readonly C_PRIMARY="#00BFFF"
readonly C_SUCCESS="#04B575"
readonly C_WARNING="#FFA500"
readonly C_DANGER="#FF4500"
readonly C_MUTED="#666666"

export GUM_SPIN_SPINNER="line"

# ── LAYER 1: UI PRIMITIVES ──────────────────────────────────────────────────
banner() { gum style --border double --border-foreground "$C_PRIMARY" --align center --padding "1 4" --bold "$*"; }
step() { gum style --foreground "$C_PRIMARY" --bold "▶  Step: ${1}"; }
ok() { gum style --foreground "$C_SUCCESS" "  ✔  $*"; }
warn() { gum style --foreground "$C_WARNING" "  ⚠  $*"; }
fail() { gum style --border thick --border-foreground "$C_DANGER" --foreground "$C_DANGER" --bold --padding "0 2" "✖  ERROR: $*"; exit 1; }
info() { gum style --foreground "$C_MUTED" "  ℹ  $*"; }

# ── LAYER 2: RUNNER HELPER ──────────────────────────────────────────────────
run_step() {
  local spinner="$1" title="$2"
  shift 2
  if gum spin --spinner "$spinner" --title "  ${title}..." -- "$@"; then
    ok "$title"
  else
    local code=$?
    fail "$title (exit $code)"
  fi
}

# ── LAYER 3: TASK FUNCTIONS ──────────────────────────────────────────────────

get_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

uninstall_brave() {
    local distro
    distro=$(get_distro)

    if ! gum confirm "Are you sure you want to uninstall Brave Beta from $distro?"; then
        info "Uninstallation cancelled."
        exit 0
    fi

    # Ensure sudo is active before running commands
    sudo -v

    case "$distro" in
        fedora)
            run_step monkey "Removing package" sudo dnf remove -y brave-browser-beta
            run_step monkey "Removing repository" sudo rm -f /etc/yum.repos.d/brave-browser-beta*.repo
            ;;
        ubuntu|debian|pop|mint)
            run_step monkey "Purging package" sudo apt purge -y brave-browser-beta
            run_step monkey "Removing source list" sudo rm -f /etc/apt/sources.list.d/brave-browser-beta*.list
            ;;
        opensuse*)
            run_step monkey "Removing package" sudo zypper remove -y brave-browser-beta
            run_step monkey "Removing repository" sudo zypper removerepo -y brave-browser-beta
            ;;
        *)
            fail "Unsupported distribution: $distro"
            ;;
    esac

    if gum confirm "Do you want to wipe Brave Beta profile data (~/.config/BraveSoftware/Brave-Browser-Beta)?"; then
        run_step monkey "Removing profile data" rm -rf "$HOME/.config/BraveSoftware/Brave-Browser-Beta/"
    fi
}

main() {
    banner "UNINSTALL BRAVE BETA"
    
    if ! command -v gum >/dev/null 2>&1; then
        fail "gum is not installed. Please install it first."
    fi

    uninstall_brave

    gum style --border rounded --border-foreground "$C_SUCCESS" --padding "1 3" "🎉 Brave Beta uninstallation complete."
}

main "$@"
