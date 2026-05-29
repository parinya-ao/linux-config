#!/usr/bin/env bash
# ==============================================================================
# Fedora Ultra Enterprise Upgrade Orchestrator
# ==============================================================================
#
# Architecture:
#   - Strict N-1 Governance
#   - Multi-Phase Validation Pipeline
#   - Offline Atomic Upgrade
#   - Rollback Awareness
#   - Transaction Safety
#   - System Health Enforcement
#   - SELinux + Boot + Kernel Validation
#   - DNF4 / DNF5 Hybrid Support
#   - Btrfs Snapshot Integration
#   - Lock-Safe Execution
#   - Enterprise Logging
#
# ==============================================================================

set -Eeuo pipefail
shopt -s inherit_errexit

readonly SELF_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Configuration
source "$SELF_DIR/config.env"

# Shared libraries
source "$SELF_DIR/lib/core.sh"
source "$SELF_DIR/lib/utils.sh"

# Pipeline modules
source "$SELF_DIR/modules/01-validate.sh"
source "$SELF_DIR/modules/02-policy.sh"
source "$SELF_DIR/modules/03-execute.sh"

# ==============================================================================
# ARGUMENT PARSER
# ==============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                AUTO_CONFIRM=1
                ;;
            --auto-reboot)
                AUTO_REBOOT=1
                ;;
            --dry-run)
                DRY_RUN=1
                ;;
            --skip-snapshot)
                SKIP_SNAPSHOT=1
                ;;
            --force)
                FORCE=1
                ;;
            *)
                log_err "Unknown argument: $1"
                exit 1
                ;;
        esac
        shift
    done
}

# ==============================================================================
# MAIN PIPELINE
# ==============================================================================

main() {
    setup_colors

    parse_args "$@"

    printf "\n${BOLD}${BLUE}"
    printf "=====================================================\n"
    printf " Fedora Ultra Enterprise Upgrade Orchestrator v%s\n" "$SCRIPT_VERSION"
    printf "=====================================================\n"
    printf "${NC}\n"

    acquire_lock
    run_validation_phase
    run_policy_phase
    run_execution_phase

    CURRENT_STATE="DONE"

    printf "\n${BOLD}${GREEN}"
    printf "=====================================================\n"
    printf " Upgrade Pipeline Completed Successfully\n"
    printf "=====================================================\n"
    printf "${NC}\n"
}

main "$@"
