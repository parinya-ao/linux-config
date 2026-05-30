#!/usr/bin/env bash
# ==============================================================================
# PHASE 2 — N-1 Governance Policy
# ==============================================================================

run_policy_phase() {
    # shellcheck disable=SC2034
    CURRENT_STATE="POLICY"

    log_info "Fetching Fedora release metadata..."

    local json
    json=$(curl -sfL --retry 5 --retry-delay 2 --max-time 20 "$RELEASES_URL")

    local latest
    latest=$(echo "$json" | jq -r '
        [
            .[]
            | .version
            | strings
            | select(test("^[0-9]+$"))
            | tonumber
        ] | max
    ')

    if [[ ! "$latest" =~ ^[0-9]+$ ]]; then
        log_err "Invalid Fedora release metadata."
        exit 1
    fi

    local n1=$((latest - 1))

    log_info "Current Fedora : $CURRENT_VER"
    log_info "Latest Fedora  : $latest"
    log_info "Enterprise N-1 : $n1"

    if [[ $CURRENT_VER -ge $n1 ]]; then
        log_warn "System already compliant with N-1 policy (Current: $CURRENT_VER)."
        log_warn "Upgrading to Latest ($latest) violates policy. Forcing DRY RUN."

        TARGET_VER="$latest"
        # shellcheck disable=SC2034
        DRY_RUN=1
    else
        local gap=$((n1 - CURRENT_VER))

        if [[ $gap -gt 1 ]]; then
            TARGET_VER=$((CURRENT_VER + 1))
            log_warn "Large version gap detected."
            log_warn "Enforcing strict +1 hop."
        else
            TARGET_VER="$n1"
        fi

        log_ok "Compliant upgrade path. Auto-confirming upgrade."
        # shellcheck disable=SC2034
        AUTO_CONFIRM=1
    fi

    if [[ $MAX_ALLOWED_VERSION -gt 0 ]] && \
       [[ $TARGET_VER -gt $MAX_ALLOWED_VERSION ]]; then
        TARGET_VER="$MAX_ALLOWED_VERSION"
        log_warn "Ceiling policy enforced."
    fi

    export TARGET_VER
    log_ok "Target Fedora version: $TARGET_VER"
}
