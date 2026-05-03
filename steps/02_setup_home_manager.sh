#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"

sync_config() {
    log_step "Synchronizing Home Manager config..."
    mkdir -p "$(dirname "$TARGET_DIR")"

    if [ ! -d "$TARGET_DIR/.git" ]; then
        log_step "Performing atomic clone..."
        git clone "$REPO_URL" "$TARGET_DIR"
    else
        log_step "Performing atomic sync (Reset Hard)..."
        git -C "$TARGET_DIR" fetch origin
        git -C "$TARGET_DIR" reset --hard origin/main 2>/dev/null || git -C "$TARGET_DIR" reset --hard origin/master
    fi
    log_ok "Configuration synced to HEAD."
}

apply_hm() {
    log_step "Activating Home Manager profile..."
    cd "$TARGET_DIR"
    
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi

    nix --extra-experimental-features "nix-command flakes" \
        run home-manager/master -- \
        switch --flake ".#parinya" -b backup
}

sync_config
apply_hm
