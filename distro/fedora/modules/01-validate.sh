#!/usr/bin/env bash
# ==============================================================================
# PHASE 1 — Validation
# ==============================================================================

run_validation_phase() {
    CURRENT_STATE="ROOT_CHECK"

    if [[ $EUID -ne 0 ]]; then
        log_err "This script must run as root."
        exit 1
    fi
    log_ok "Root validation passed."

    CURRENT_STATE="ENVIRONMENT"

    local required=(rpm dnf curl jq awk grep sed findmnt systemctl uname df)
    for bin in "${required[@]}"; do
        command -v "$bin" >/dev/null 2>&1 || {
            log_err "Missing dependency: $bin"
            exit 1
        }
    done

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "$ID" != "fedora" ]]; then
        log_err "Unsupported OS: $ID"
        exit 1
    fi

    CURRENT_VER="$(rpm -E %fedora)"

    if command -v dnf5 >/dev/null 2>&1; then
        # shellcheck disable=SC2034
        IS_DNF5=1
    fi

    log_ok "Environment validation complete."
    log_info "Detected Fedora $CURRENT_VER"

    CURRENT_STATE="SYSTEM_HEALTH"

    if ! systemctl is-system-running --quiet; then
        log_warn "Systemd reports degraded state."

        if [[ $FORCE -eq 0 ]]; then
            log_err "Use --force to bypass degraded-state protection."
            exit 1
        fi
    fi

    if sestatus | grep -q "disabled"; then
        log_warn "SELinux disabled."
    else
        log_ok "SELinux enabled."
    fi

    if [[ ! -d /sys/firmware/efi ]]; then
        log_warn "Legacy BIOS detected."
    else
        log_ok "UEFI firmware detected."
    fi

    CURRENT_STATE="STORAGE"

    local checks=(
        "/:$MIN_ROOT_MB"
        "/var:$MIN_VAR_MB"
        "/boot:$MIN_BOOT_MB"
    )

    if [[ -d /boot/efi ]]; then
        checks+=("/boot/efi:$MIN_EFI_MB")
    fi

    for entry in "${checks[@]}"; do
        local path="${entry%%:*}"
        local req="${entry##*:}"

        if [[ -d "$path" ]]; then
            local free_kb
            free_kb=$(df -P "$path" | awk 'NR==2 {print $4}')
            local free_mb=$((free_kb / 1024))

            if [[ $free_mb -lt $req ]]; then
                log_err "Insufficient free space on $path"
                log_err "Required: ${req}MB | Available: ${free_mb}MB"
                exit 1
            fi
        fi
    done

    log_ok "Disk capacity validated."

    # shellcheck disable=SC2034
    CURRENT_STATE="REPOSITORIES"

    local safe_regex="^(fedora|updates|updates-testing|fedora-cisco-openh264)"
    local repos
    repos=$(timeout 30s dnf repolist enabled -q | awk 'NR>1 {print $1}' || echo "")

    local found=0
    for repo in $repos; do
        if ! [[ "$repo" =~ $safe_regex ]]; then
            [[ $found -eq 0 ]] && log_warn "Third-party repositories detected:"
            printf "   - %s\n" "$repo"
            found=1
        fi
    done

    log_ok "Repository audit completed."
}
