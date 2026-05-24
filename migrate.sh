#!/usr/bin/env bash
# ==============================================================================
# Script: mirate.sh
# Description: Pure-Modular Nix Flake Updater (KISS, Open Architecture, CI/CD Ready)
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. State Variables (Initialized empty, populated only upon execution)
# ------------------------------------------------------------------------------
LOCK_BACKUP=""
UPDATE_LOG=""

# ------------------------------------------------------------------------------
# 2. UI & Logging Modules (CI/CD Compliant)
# ------------------------------------------------------------------------------
setup_colors() {
    # Check if standard output is a terminal (TTY)
    if [[ -t 1 ]]; then
        C_RED='\033[0;31m'
        C_GREEN='\033[0;32m'
        C_YELLOW='\033[0;33m'
        C_BLUE='\033[0;34m'
        C_CYAN='\033[0;36m'
        C_BOLD='\033[1m'
        C_NC='\033[0m'
    else
        # Disable colors for raw log files or CI/CD environments
        C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_BOLD=''; C_NC=''
    fi
}

print_step()    { printf "\n${C_BLUE}${C_BOLD}▶ %s${C_NC}\n" "$1"; }
print_success() { printf "  ${C_GREEN}✔ SUCCESS:${C_NC} %s\n" "$1"; }
print_info()    { printf "  ${C_CYAN}ℹ INFO:${C_NC} %s\n" "$1"; }
print_error()   { printf "\n  ${C_RED}✖ ERROR:${C_NC} %s\n" "$1" >&2; }

# ------------------------------------------------------------------------------
# 3. Resiliency Module (File-State based Rollback)
# ------------------------------------------------------------------------------
rollback_on_error() {
    local exit_code=$?
    trap - ERR INT TERM # Prevent recursive trap calls

    print_error "Process interrupted or failed. Initiating rollback sequence..."

    # Rely entirely on File-System state (KISS Principle)
    if [[ -n "${LOCK_BACKUP:-}" && -f "$LOCK_BACKUP" ]]; then
        print_info "Restoring stable flake.lock from backup..."
        mv "$LOCK_BACKUP" flake.lock
        print_success "Rollback complete. System integrity secured."
    fi

    if [[ -n "${UPDATE_LOG:-}" && -f "$UPDATE_LOG" ]]; then
        rm -f "$UPDATE_LOG"
    fi

    exit "$exit_code"
}

# ------------------------------------------------------------------------------
# 4. Core Business Logic (Pure Functions, No Global State Dependencies)
# ------------------------------------------------------------------------------
verify_environment() {
    print_step "Verifying Environment..."
    if ! command -v nix >/dev/null 2>&1; then
        print_error "Nix package manager is not installed."
        return 1
    fi
    if [[ ! -f "flake.nix" ]]; then
        print_error "flake.nix not found in $(pwd)."
        return 1
    fi
    print_success "Environment is valid."
}

backup_lockfile() {
    local backup_path="$1"
    print_step "Securing Lockfile..."
    if [[ -f "flake.lock" ]]; then
        cp flake.lock "$backup_path"
        print_success "Lockfile backed up to ${backup_path}"
    else
        print_info "No existing lockfile. Proceeding with fresh generation."
    fi
}

execute_migration() {
    local log_path="$1"
    shift
    local targets=("$@") # Can handle multiple inputs natively
    
    print_step "Updating Targets: ${targets[*]}"
    print_info "Fetching updates from upstream..."

    # Pass all targets directly to the Nix command
    nix --extra-experimental-features "nix-command flakes" \
        flake update "${targets[@]}" > "$log_path" 2>&1 || return 1
        
    print_success "Update command executed."
}

analyze_changes() {
    local log_path="$1"
    print_step "Migration Summary"
    
    local changes
    changes=$(grep -vE "^warning:|^$" "$log_path" || true)
    
    if [[ -n "$changes" ]]; then
        printf "%s\n" "$changes" | sed 's/^/      /'
        print_info "Dependencies advanced successfully."
    else
        print_info "No changes. All inputs are up-to-date."
    fi
}

integration_test() {
    local targets=("$@")
    print_step "Running Integration Tests..."
    
    if [[ ! -f "flake.lock" ]]; then
        print_error "flake.lock is missing."
        return 1
    fi
    
    if ! nix --extra-experimental-features "nix-command flakes" flake metadata >/dev/null 2>&1; then
        print_error "Flake metadata verification failed. Corrupted JSON."
        return 1
    fi
    
    # Verify every requested target exists in the new lockfile
    for target in "${targets[@]}"; do
        if ! grep -q "\"$target\"" flake.lock; then
            print_error "Target '$target' is missing from flake.lock."
            return 1
        fi
    done
    
    print_success "All integrity checks passed."
}

cleanup() {
    local backup_path="$1"
    local log_path="$2"
    print_step "Cleaning Up..."
    
    rm -f "$backup_path" "$log_path"
    print_success "Temporary files removed."
}

# ------------------------------------------------------------------------------
# 5. Main Orchestrator (Open-Closed Principle)
# ------------------------------------------------------------------------------
main() {
    setup_colors
    
    # Accept user arguments or default to 'nixpkgs'
    local targets=("${@:-nixpkgs}")
    
    # Secure variables initialized ONLY upon execution
    LOCK_BACKUP="flake.lock.bak"
    UPDATE_LOG="$(mktemp /tmp/nix_update_XXXXXX.log)"

    # Attach trap to main workflow
    trap 'rollback_on_error' ERR INT TERM

    printf "\n${C_BOLD}${C_CYAN}=== Nix Flake Migration Assistant ===${C_NC}\n"
    
    # Dependency Injection pattern: passing parameters instead of reading globals
    verify_environment
    backup_lockfile "$LOCK_BACKUP"
    execute_migration "$UPDATE_LOG" "${targets[@]}"
    analyze_changes "$UPDATE_LOG"
    integration_test "${targets[@]}"
    cleanup "$LOCK_BACKUP" "$UPDATE_LOG"
    
    printf "\n${C_BOLD}${C_GREEN}✨ Migration completed perfectly! ✨${C_NC}\n\n"
}

# Only execute main if the script is invoked directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
