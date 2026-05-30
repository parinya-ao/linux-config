#!/usr/bin/env nix-shell
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
        gum spin --spinner line --title "Staging untracked files to Git..." -- git add -A
        ok "Git tree is clean and ready for Flake."
    fi
}

fix_trusted_user() {
    local conf_file="/etc/nix/nix.conf"
    if [[ -f "$conf_file" ]] && ! grep -qE "^trusted-users\s*=.*(\b$USER\b|\b@wheel\b)" "$conf_file"; then
        warn "Untrusted user detected. Fixing /etc/nix/nix.conf (Requires sudo)..."
        if sudo bash -c "echo 'trusted-users = root @wheel $USER' >> $conf_file"; then
            gum spin --spinner points --title "Restarting nix-daemon..." -- sudo systemctl restart nix-daemon || true
            ok "Added $USER to trusted-users. Cache warnings resolved."
        else
            fail "Could not modify nix.conf."
        fi
    fi
}

auto_fix_versions() {
    if grep -qE 'github:nixos/nixpkgs/.*unstable' flake.nix; then
        gum spin --spinner minidot --title "Aligning Home Manager branch to Master..." -- \
            sed -i -E "s|(github:nix-community/home-manager/)[a-zA-Z0-9._-]+|\1master|g" flake.nix
    else
        local nix_ver=$(grep -E 'github:nixos/nixpkgs/' flake.nix | grep -oE '[0-9]+\.[0-9]+' | head -n1 || true)
        if [[ -n "$nix_ver" ]]; then
            gum spin --spinner minidot --title "Aligning Home Manager branch to release-${nix_ver}..." -- \
                sed -i -E "s|(github:nix-community/home-manager/)[a-zA-Z0-9._-]+|\1release-${nix_ver}|g" flake.nix
        fi
    fi
}

# ------------------------------------------------------------------------------
# 4. Core Business Logic
# ------------------------------------------------------------------------------
main() {
    trap 'rollback_on_error' ERR INT TERM

    clear
    gum style --border double --margin "1" --padding "1 2" --border-foreground "#00BFFF" "❄️  Nix Flake Migration Assistant"

    step "Pre-flight Checks & Auto-Fixes"
    fix_trusted_user
    auto_fix_versions
    fix_git_state

    step "Securing Environment"
    [[ -f "flake.lock" ]] && cp flake.lock flake.lock.bak && ok "Lockfile backed up."

    step "Fetching Updates (Showing inner details...)"
    if nix --extra-experimental-features "nix-command flakes" flake update; then
        ok "Flake lockfile updated successfully."
    else
        fail "Failed to update flake inputs."
    fi

    step "Applying Configuration (Showing inner details...)"
    if home-manager switch --flake . --verbose --show-trace -b backup; then
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
