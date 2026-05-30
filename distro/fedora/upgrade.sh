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

readonly SELF_DIR
SELF_DIR="$(dirname "${BASH_SOURCE[0]}")"

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
                # shellcheck disable=SC2034
                AUTO_CONFIRM=1
                ;;
            --auto-reboot)
                # shellcheck disable=SC2034
                AUTO_REBOOT=1
                ;;
            --dry-run)
                # shellcheck disable=SC2034
                DRY_RUN=1
                ;;
            --skip-snapshot)
                # shellcheck disable=SC2034
                SKIP_SNAPSHOT=1
                ;;
            --force)
                # shellcheck disable=SC2034
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

    printf '\n%s%s' "$BOLD" "$BLUE"
    printf '=====================================================\n'
    printf ' Fedora Ultra Enterprise Upgrade Orchestrator v%s\n' "$SCRIPT_VERSION"
    printf '=====================================================\n'
    printf '%s\n' "$NC"

    acquire_lock
    run_validation_phase
    run_policy_phase
    run_execution_phase

    # shellcheck disable=SC2034
    CURRENT_STATE="DONE"

    printf '\n%s%s' "$BOLD" "$GREEN"
    printf '=====================================================\n'
    printf ' Upgrade Pipeline Completed Successfully\n'
    printf '=====================================================\n'
    printf '%s\n' "$NC"
}

main "$@"
