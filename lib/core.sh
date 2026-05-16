#!/usr/bin/env bash
# lib/core.sh

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export GIT_TERMINAL_PROMPT=0

LOG_FILE="$HOME/startup_$(date +%Y%m%d_%H%M%S).log"
TARGET_DIR="${HOME}/.config/home-manager"
REPO_URL="https://github.com/parinya-ao/linux-config.git"

BOLD='\033[1m' ; RESET='\033[0m' ; RED='\033[1;31m' ; GREEN='\033[1;32m' ; BLUE='\033[1;34m' ; YELLOW='\033[1;33m'

log_step() { log "STEP" "$@"; }
log_info() { log "INFO" "$@"; }
log_ok() { log "OK" "$@"; }
abort() { log "FAIL" "$@"; exit 1; }

log() {
    local level="$1"; shift
    local color=""
    case "$level" in
        "STEP") color="$BLUE" ;;
        "OK")   color="$GREEN" ;;
        "WARN") color="$YELLOW" ;;
        "FAIL") color="$RED" ;;
        "INFO") color="$YELLOW" ;;
    esac
    printf "%b[%s]%b %s\n" "$color" "$level" "$RESET" "$*" | tee -a "$LOG_FILE"
}

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log "FAIL" "Execution failed with exit code $exit_code. Check $LOG_FILE"
    fi
    exit $exit_code
}

trap cleanup EXIT
