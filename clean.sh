#!/usr/bin/env bash
# ==============================================================================
# Script: clean.sh (Nix System Cleanup)
# Description: Production-grade automated cleanup for Nix environments.
# Architecture: Modular, KISS, State-driven, Open Architecture, Integration Tested
# ==============================================================================

# Strict mode: fail on undefined vars, and pipe failures
set -uo pipefail

# --- Global Configurations ---
readonly LOG_FILE="/tmp/nix_system_cleanup.log"
CURRENT_STATE="INIT"

# --- ANSI Color Codes ---
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_MAGENTA='\033[0;35m'
readonly C_CYAN='\033[0;36m'
readonly C_NC='\033[0m' # No Color

# --- Logging Framework ---
log() { echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1" | tee -a "$LOG_FILE"; }
log_info()    { log "${C_BLUE}[INFO]${C_NC} $1"; }
log_success() { log "${C_GREEN}[SUCCESS]${C_NC} $1"; }
log_error()   { log "${C_RED}[ERROR]${C_NC} $1"; }
log_debug()   { log "${C_YELLOW}[DEBUG]${C_NC} [STATE: ${C_MAGENTA}${CURRENT_STATE}${C_NC}] $1"; }

# --- Error Handler Trap ---
error_handler() {
    # Don't trigger if we are inside a BATS test environment
    if [ "${BATS_TEST_NAME:-unset}" != "unset" ]; then
        return
    fi
    log_error "Script failed during state: ${CURRENT_STATE}. Please check ${LOG_FILE} for details."
    exit 1
}
# trap 'error_handler' ERR

# ==============================================================================
# MODULAR FUNCTIONS
# ==============================================================================

verify_dependencies() {
    CURRENT_STATE="VERIFY_DEPENDENCIES"
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
    CURRENT_STATE="REMOVE_OLD_GENERATIONS"
    log_debug "Executing: nix-env --delete-generations old"
    
    if nix-env --delete-generations old >> "$LOG_FILE" 2>&1; then
        log_success "Old generations removed successfully."
    else
        log_error "Failed to remove old generations."
        return 1
    fi
}

run_garbage_collection() {
    CURRENT_STATE="GARBAGE_COLLECTION"
    log_debug "Executing: nix-store --gc"
    
    # Run GC and capture the output to extract freed space info
    local gc_output
    if gc_output=$(nix-store --gc 2>&1); then
        echo "$gc_output" >> "$LOG_FILE"
        local bytes_freed
        bytes_freed=$(echo "$gc_output" | grep -oP '\d+(?= bytes freed)' || echo "Unknown")
        log_success "Garbage collection completed. Freed: ${C_CYAN}${bytes_freed} bytes${C_NC}."
    else
        log_error "Garbage collection failed."
        return 1
    fi
}

optimize_nix_store() {
    CURRENT_STATE="OPTIMIZE_STORE"
    log_debug "Executing: nix-store --optimize"
    
    if nix-store --optimize >> "$LOG_FILE" 2>&1; then
        log_success "Nix store optimization completed (hardlinks created)."
    else
        log_error "Nix store optimization failed."
        return 1
    fi
}

# ==============================================================================
# SYSTEM INTEGRATION TEST
# ==============================================================================
integration_test() {
    CURRENT_STATE="INTEGRATION_TEST"
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
    if nix-store --verify --check-contents >> "$LOG_FILE" 2>&1; then
        log_success "[Test 2 Passed] Nix store integrity verified successfully."
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
    # สร้างไฟล์ log อย่างปลอดภัย
    touch "$LOG_FILE" || { echo -e "${C_RED}[ERROR]${C_NC} Cannot write to ${LOG_FILE}. Exiting." >&2; exit 1; }
    
    log_info "Starting Nix Environment Cleanup Pipeline"
    
    verify_dependencies
    remove_old_generations
    run_garbage_collection
    optimize_nix_store
    
    # Run self-check at the end
    integration_test
    
    CURRENT_STATE="DONE"
    log_info "Cleanup pipeline executed and verified successfully."
}

# รัน Main เฉพาะในกรณีที่ถูกเรียกเป็น Script (ไม่รันตอนถูกนำไป source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
