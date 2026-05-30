#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/core.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/system.sh"

dispatch_distro() {
    log_step "Detecting OS Architecture..."
    if [ ! -f /etc/os-release ]; then abort "OS release info missing"; fi
    # shellcheck disable=SC1091
    . /etc/os-release

    local script_path=""
    case "${ID:-}" in
        fedora) script_path="$SCRIPT_DIR/distro/fedora/fedora.sh" ;;
        ubuntu|debian|pop|linuxmint) script_path="$SCRIPT_DIR/distro/ubuntu/ubuntu.sh" ;;
        opensuse*|suse) script_path="$SCRIPT_DIR/distro/opensuse/opensuse.sh" ;;
        *)
            if [[ "${ID_LIKE:-}" == *"fedora"* ]]; then script_path="$SCRIPT_DIR/distro/fedora/fedora.sh"
            elif [[ "${ID_LIKE:-}" == *"debian"* ]]; then script_path="$SCRIPT_DIR/distro/ubuntu/ubuntu.sh"
            elif [[ "${ID_LIKE:-}" == *"suse"* ]]; then script_path="$SCRIPT_DIR/distro/opensuse/opensuse.sh"
            else abort "Unsupported OS: ${ID:-unknown}"; fi
            ;;
    esac

    if [ ! -f "$script_path" ]; then
        abort "Distro script not found: $script_path"
    fi

    # ✅ RETRY LOOP — continue until distro script exits with 0
    local round=1
    local CONTINUE_SIGNAL=42

    while true; do
        log_step "Executing Distro Driver: Round ${round} (with sudo)"
        sudo bash "$script_path"
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            log_ok "Distro driver completed successfully (Round ${round})."
            break  # Completed successfully, exit loop
        elif [ $exit_code -eq $CONTINUE_SIGNAL ]; then
            log_info "Round ${round} done — re-running for next phase..."
            round=$((round + 1))
            sleep 1
        else
            abort "Distro driver failed with exit code $exit_code at Round ${round}!"
        fi
    done
}

check_requirements
dispatch_distro
