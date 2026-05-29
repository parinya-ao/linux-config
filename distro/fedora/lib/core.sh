# ==============================================================================
# CORE SHARED LIBRARY — colors, logging, error handling
# ==============================================================================

setup_colors() {
    if [[ -t 1 ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        BOLD='\033[1m'
        NC='\033[0m'
    else
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        BOLD=''
        NC=''
    fi
}

log() {
    local level="$1"
    local color="$2"
    local msg="$3"

    printf "%b[%s]%b [%s] %s\n" \
        "$color" "$level" "$NC" "$CURRENT_STATE" "$msg"

    printf "[%s] [%s] [%s] %s\n" \
        "$(date '+%F %T')" \
        "$level" \
        "$CURRENT_STATE" \
        "$msg" >> "$LOG_FILE"
}

log_info() { log "INFO" "$BLUE" "$1"; }
log_ok()   { log " OK " "$GREEN" "$1"; }
log_warn() { log "WARN" "$YELLOW" "$1"; }
log_err()  { log "ERR " "$RED" "$1"; }

cleanup_on_error() {
    local exit_code=$?

    trap - ERR INT TERM

    log_err "Fatal pipeline failure detected. Exit code: $exit_code"

    if [[ "$CURRENT_STATE" == "DOWNLOAD" ]] || \
       [[ "$CURRENT_STATE" == "UPGRADE" ]]; then
        log_warn "Upgrade cache may be inconsistent."

        if [[ $IS_DNF5 -eq 1 ]]; then
            log_info "Recovery: sudo dnf offline-upgrade clean"
        else
            log_info "Recovery: sudo dnf system-upgrade clean"
        fi
    fi

    exit "$exit_code"
}

trap cleanup_on_error ERR INT TERM
