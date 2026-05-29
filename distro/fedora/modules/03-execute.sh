# ==============================================================================
# PHASE 3 — Execution
# ==============================================================================

run_execution_phase() {

    CURRENT_STATE="SNAPSHOT"

    if [[ $SKIP_SNAPSHOT -eq 1 ]]; then
        log_warn "Snapshot creation skipped."
    elif findmnt -n -o FSTYPE / | grep -q "btrfs"; then
        if command -v snapper >/dev/null 2>&1; then
            if [[ $DRY_RUN -eq 0 ]]; then
                snapper create -t pre -c number -d "Fedora pre-upgrade F${CURRENT_VER}"
            fi
            log_ok "Pre-upgrade snapshot created."
        else
            log_warn "Btrfs detected without snapper."
        fi
    else
        log_info "Non-Btrfs filesystem detected."
    fi

    CURRENT_STATE="REFRESH"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Skipping package refresh."
    else
        log_info "Refreshing current system packages..."
        dnf upgrade --refresh -y
        log_ok "Base system updated."
    fi

    CURRENT_STATE="REBOOT_CHECK"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Skipping kernel reboot checks."
    else
        local reboot_required=0

        if command -v needs-rebooting >/dev/null 2>&1; then
            set +e
            needs-rebooting -r >/dev/null 2>&1
            [[ $? -eq 1 ]] && reboot_required=1
            set -e
        else
            local current_kernel
            current_kernel="$(uname -r)"

            local installed_kernel
            installed_kernel="$(rpm -q kernel \
                --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' \
                | sort -V | tail -n 1)"

            [[ "$current_kernel" != "$installed_kernel" ]] && reboot_required=1
        fi

        if [[ $reboot_required -eq 1 ]]; then
            log_warn "Kernel mismatch detected."
            log_warn "Reboot required before upgrade."

            if [[ -f "$REBOOT_MARKER" ]]; then
                log_err "Reboot loop protection triggered."
                exit 1
            fi

            if [[ $AUTO_REBOOT -eq 1 ]]; then
                touch "$REBOOT_MARKER"
                log_info "Automatic reboot initiated."
                reboot
                exit 0
            fi

            log_err "Please reboot and re-run script."
            exit 100
        fi

        rm -f "$REBOOT_MARKER"
        log_ok "Kernel state validated."
    fi

    CURRENT_STATE="DOWNLOAD"

    local args=(
        "--releasever=$TARGET_VER"
        "--allowerasing"
    )

    [[ $IS_DNF5 -eq 0 ]] && args+=("--best")
    [[ $DRY_RUN -eq 1 ]] && args+=("--downloadonly" "--setopt=tsflags=test")

    if [[ $AUTO_CONFIRM -eq 0 ]] && [[ $DRY_RUN -eq 0 ]]; then
        read -rp "Proceed with Fedora $TARGET_VER upgrade? [y/N]: " confirm
        [[ "${confirm,,}" != "y" ]] && {
            log_warn "Upgrade cancelled."
            exit 0
        }
    fi

    log_info "Downloading upgrade payload..."

    if [[ $IS_DNF5 -eq 1 ]]; then
        dnf offline-upgrade download "${args[@]}" -y
    else
        dnf install -y dnf-plugin-system-upgrade
        dnf system-upgrade download "${args[@]}" -y
    fi

    log_ok "Upgrade payload ready."

    CURRENT_STATE="UPGRADE"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_ok "[DRY RUN] Dependency graph clean."
        exit 0
    fi

    if [[ $AUTO_REBOOT -eq 1 ]]; then
        log_info "Rebooting into offline upgrade mode..."

        if [[ $IS_DNF5 -eq 1 ]]; then
            dnf offline-upgrade reboot
        else
            dnf system-upgrade reboot
        fi
    else
        log_ok "Upgrade staged successfully."

        if [[ $IS_DNF5 -eq 1 ]]; then
            log_info "Execute: sudo dnf offline-upgrade reboot"
        else
            log_info "Execute: sudo dnf system-upgrade reboot"
        fi
    fi
}
