#!/usr/bin/env nix-shell
# shellcheck shell=bash
#!nix-shell -i bash -p gum git
# ==============================================================================
# Script: migrate.sh
# Description: Pure-Modular Nix Flake Updater (100% Auto-fixes, Gum UI)
# Architecture: KISS, State-driven, Out-of-the-box
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. UI Helpers (Powered by Gum) - Standardized across all scripts
# ------------------------------------------------------------------------------
step() { gum style --foreground "#00BFFF" --bold "▶ $*"; }
ok()   { gum style --foreground "#04B575" "  ✔ $*"; }
warn() { gum style --foreground "#FFA500" "  ⚠ $*" >&2; }
info() { gum style --foreground "#00BFFF" "  ℹ $*"; }
fail() { gum style --foreground "#FF4500" --bold "  ✖ $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# 2. Resiliency & Rollback
# ------------------------------------------------------------------------------
# shellcheck disable=SC2317
rollback_on_error() {
    local exit_code=$?
    trap - ERR INT TERM
    fail "Process interrupted! Rolling back..."
    [[ -f "flake.lock.bak" ]] && mv "flake.lock.bak" "flake.lock" && ok "Lockfile restored."
    exit "$exit_code"
}

# ------------------------------------------------------------------------------
# 3. 100% Automation & Auto-Fixes
# ------------------------------------------------------------------------------
fix_git_state() {
    if ! git diff-index --quiet HEAD -- || git ls-files --others --exclude-standard | grep -q "."; then
        info "Staging untracked files to Git..."
        git add -A
        ok "Git tree is clean and ready for Flake."
    fi
}

fix_trusted_user() {
    local conf_file="/etc/nix/nix.conf"
    local custom_conf="/etc/nix/nix.custom.conf"
    local target_conf="$conf_file"
    
    # Target custom_conf if it exists (Determinate Nix style)
    [[ -f "$custom_conf" ]] && target_conf="$custom_conf"
    
    local current_user
    current_user=$(whoami)

    if ! grep -qE "^trusted-users\s*=.*(\b$current_user\b|\b@wheel\b)" "$target_conf" 2>/dev/null; then
        warn "Untrusted user detected. Fixing $target_conf (Requires sudo)..."
        
        # Ensure the directory exists
        sudo mkdir -p "$(dirname "$target_conf")"
        
        # If the file doesn't exist, create it
        if [[ ! -f "$target_conf" ]]; then
            sudo bash -c "echo 'trusted-users = root @wheel $current_user' > $target_conf"
        # If trusted-users line exists, append the user
        elif grep -q "^trusted-users\s*=" "$target_conf"; then
            sudo sed -i "s/^trusted-users\s*=.*/& $current_user/" "$target_conf"
        # Otherwise, append a new line
        else
            sudo bash -c "echo 'trusted-users = root @wheel $current_user' >> $target_conf"
        fi

        # Inform the user (daemon restart disabled by request)
        info "Trusted users updated. A manual restart of nix-daemon (sudo systemctl restart nix-daemon) may be required for changes to take effect."
        ok "Added $current_user to trusted-users in $target_conf."
    fi
}

fix_dbus() {
    local legacy_conf="/etc/dbus-1/session.conf"
    if [[ -f "$legacy_conf" ]]; then
        # If it's the problematic empty config on Fedora
        if grep -q "<busconfig></busconfig>" "$legacy_conf"; then
            warn "Legacy/broken DBus session config detected at $legacy_conf. Fixing..."
            sudo rm -f "$legacy_conf"
            ok "Removed legacy DBus session config."
        fi
    fi
}

auto_fix_versions() {
    if grep -qE 'github:nixos/nixpkgs/.*unstable' flake.nix; then
        info "Aligning Home Manager branch to Master..."
        sed -i -E "s|(github:nix-community/home-manager/)[a-zA-Z0-9._-]+|\1master|g" flake.nix
    else
        local nix_ver
        nix_ver=$(grep -E 'github:nixos/nixpkgs/' flake.nix | grep -oE '[0-9]+\.[0-9]+' | head -n1 || true)
        if [[ -n "$nix_ver" ]]; then
            info "Aligning Home Manager branch to release-${nix_ver}..."
            sed -i -E "s|(github:nix-community/home-manager/)[a-zA-Z0-9._-]+|\1release-${nix_ver}|g" flake.nix
        fi
    fi
}

# ------------------------------------------------------------------------------
# 4. Core Business Logic
# ------------------------------------------------------------------------------
main() {
    trap 'rollback_on_error' ERR INT TERM

    # DEBUG MODE: If DEBUG=1 is set, enable shell tracing
    if [[ "${DEBUG:-0}" == "1" ]]; then
        set -x
    fi

    # clear  # REMOVED: No black box, keep terminal history
    gum style --border double --margin "1" --padding "1 2" --border-foreground "#00BFFF" "❄️  Nix Flake Migration Assistant [DEBUG ENABLED]"

    step "Pre-flight Checks & Auto-Fixes"
    fix_trusted_user
    fix_dbus
    auto_fix_versions
    fix_git_state

    step "Securing Environment"
    [[ -f "flake.lock" ]] && cp flake.lock flake.lock.bak && ok "Lockfile backed up."

    step "Fetching Updates (Direct execution for transparency...)"
    # REPLACED gum spin with direct execution
    if nix --extra-experimental-features "nix-command flakes" flake update; then
        ok "Flake lockfile updated successfully."
    else
        fail "Failed to update flake inputs."
    fi

    step "Applying Configuration (Direct execution for transparency...)"
    local hm_cmd=(home-manager)
    if ! command -v home-manager >/dev/null 2>&1; then
        warn "home-manager command not found in PATH, using 'nix run' fallback..."
        hm_cmd=(nix --extra-experimental-features "nix-command flakes" run home-manager/master --)
    fi

    # Robust DBus handling for dconf activation
    local run_cmd=("${hm_cmd[@]}")
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && command -v dbus-run-session >/dev/null 2>&1; then
        info "No DBus session found. Wrapping switch in dbus-run-session..."
        run_cmd=(dbus-run-session -- "${hm_cmd[@]}")
    fi

    # REPLACED gum spin with direct execution
    if "${run_cmd[@]}" switch --flake . --verbose --show-trace -b backup; then
        ok "System configured beautifully."
    else
        fail "Home Manager switch failed."
    fi

    rm -f flake.lock.bak

    echo ""
    gum format -- "- **Migration Complete!** Your environment is now up-to-date and pristine." "- Run \`home-manager news\` if you want to check recent changes."
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
