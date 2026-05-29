# ==============================================================================
# UTILITY SHARED LIBRARY — lock, shared helpers
# ==============================================================================

acquire_lock() {
    CURRENT_STATE="LOCK"

    exec 9>"$LOCK_FILE"

    if ! flock -n 9; then
        log_err "Another upgrade instance is already running."
        exit 1
    fi

    log_ok "Execution lock acquired."
}
