#!/usr/bin/env nix-shell
#!nix-shell -i bash -p gum
# ==============================================================================
# Script: clean.sh (Nix System Cleanup)
# Description: Production-grade automated cleanup for Nix environments.
# Architecture: Modular, KISS, State-driven, Open Architecture, Integration Tested
# UI: Gum-powered, Minimalist, 100% Non-interactive
# ==============================================================================

set -euo pipefail

# ── Global Configurations ─────────────────────────────────────────────────────
readonly LOG_FILE="/tmp/nix_system_cleanup.log"

# ── Gum-based UI (no raw ANSI codes) ─────────────────────────────────────────
step() { gum style --foreground "#00BFFF" --bold "▶ $*"; }
ok()   { gum style --foreground "#04B575" "  ✔ $*"; }
warn() { gum style --foreground "#FFA500" "  ⚠ $*" >&2; }
fail() { gum style --foreground "#FF4500" --bold "  ✖ $*" >&2; exit 1; }

# ── Logging Framework (to file only) ─────────────────────────────────────────
log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1" >> "$LOG_FILE"; }
log_info()    { log "[INFO] $1"; }
log_success() { log "[SUCCESS] $1"; }
log_error()   { log "[ERROR] $1"; }
log_debug()   { log "[DEBUG] $1"; }

# ── Error Handler Trap ───────────────────────────────────────────────────────
error_handler() {
    # Don't trigger if we are inside a BATS test environment
    if [ "${BATS_TEST_NAME:-unset}" != "unset" ]; then
        return
    fi
    log_error "Script failed. Please check ${LOG_FILE} for details."
    fail "Cleanup failed. See $LOG_FILE for details."
}
trap 'error_handler' ERR

# ── Helpers ──────────────────────────────────────────────────────────────────
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

# ==============================================================================
# MODULAR FUNCTIONS
# ==============================================================================

verify_dependencies() {
    log_debug "Checking for required Nix commands..."
    
    for cmd in nix-env nix-store; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Command '$cmd' not found. Is Nix installed?"
            exit 1
        fi
    done
    log_success "All Nix dependencies found."
}

remove_old_generations() {
    log_debug "Executing: nix-env --delete-generations old"
    
    if gum spin --spinner line --title "Removing old generations..." -- \
        nix-env --delete-generations old >> "$LOG_FILE" 2>&1; then
        log_success "Old generations removed successfully."
        ok "Old generations removed"
    else
        log_error "Failed to remove old generations."
        return 1
    fi
}

run_garbage_collection() {
    log_debug "Executing: nix-store --gc"
    
    # Run GC and capture the output to extract freed space info
    local gc_output
    if gum spin --spinner globe --title "Cleaning up Nix store..." -- \
        bash -c "gc_output=\$(nix-store --gc 2>&1); echo \"\$gc_output\" >> \"$LOG_FILE\"; echo \"\$gc_output\""; then
        echo "$gc_output" >> "$LOG_FILE"
        local bytes_freed
        bytes_freed=$(echo "$gc_output" | grep -oP '\d+(?= bytes freed)' || echo "Unknown")
        log_success "Garbage collection completed. Freed: ${bytes_freed} bytes."
        ok "Garbage collection completed"
    else
        log_error "Garbage collection failed."
        return 1
    fi
}

optimize_nix_store() {
    log_debug "Executing: nix-store --optimize"
    
    if gum spin --spinner points --title "Optimizing Nix store..." -- \
        nix-store --optimize >> "$LOG_FILE" 2>&1; then
        log_success "Nix store optimization completed (hardlinks created)."
        ok "Nix store optimized"
    else
        log_error "Nix store optimization failed."
        return 1
    fi
}

# ==============================================================================
# SYSTEM INTEGRATION TEST
# ==============================================================================
integration_test() {
    log_info "Initiating system integration tests for cleanup state..."
    
    # Test 1: Verify 'nix-env --list-generations' doesn't fail
    log_debug "Test 1: Validating current generation state..."
    if nix-env --list-generations >/dev/null 2>&1; then
        log_success "[Test 1 Passed] Generation list is accessible and intact."
    else
        log_error "[Test 1 Failed] Cannot list generations. Profile might be corrupted."
        exit 1
    fi
    
    # Test 2: Verify Nix store health after GC and Optimization
    log_debug "Test 2: Verifying Nix store paths..."
    if gum spin --spinner dot --title "Verifying Nix store integrity..." -- \
        nix-store --verify --check-contents >> "$LOG_FILE" 2>&1; then
        log_success "[Test 2 Passed] Nix store integrity verified successfully."
        ok "Nix store verified"
    else
        log_error "[Test 2 Failed] Nix store verification failed. Corrupted paths detected."
        exit 1
    fi
    
    log_success "All system integration tests passed flawlessly."
}

# ==============================================================================
# MAIN EXECUTION (Open Architecture)
# ==============================================================================
main() {
    # Create log file safely
    touch "$LOG_FILE" || { echo "Cannot write to ${LOG_FILE}. Exiting." >&2; exit 1; }
    
    log_info "Starting Nix Environment Cleanup Pipeline"
    gum style --border double --margin "1" --padding "1 2" --border-foreground "#00BFFF" \
        "$(gum style --bold --foreground "#00BFFF" "🧹 Nix System Cleanup")"
    
    verify_dependencies
    remove_old_generations
    run_garbage_collection
    optimize_nix_store
    
    # Run self-check at the end
    integration_test
    
    log_info "Cleanup pipeline executed and verified successfully."
    
    echo ""
    gum format -- "✅ **Cleanup Complete!** Your Nix environment is now pristine." \
        "" \
        "📋 Log file: $LOG_FILE" \
        "" \
        "$(gum style --italic --foreground "#FFA500" "Run \`nix-env --list-generations\` to see current generations.")"
}

# Run Main only when script is executed (not when sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
