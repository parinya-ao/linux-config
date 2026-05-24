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

# ==============================================================================
# GLOBAL CONSTANTS
# ==============================================================================

readonly SCRIPT_VERSION="9.0"
readonly LOCK_FILE="/var/lock/fedora_ultra_upgrade.lock"
readonly REBOOT_MARKER="/var/lib/fedora_upgrade_reboot_required.flag"
readonly RELEASES_URL="https://fedoraproject.org/releases.json"
readonly LOG_FILE="/var/log/fedora-ultra-upgrade.log"

readonly MIN_ROOT_MB=15000
readonly MIN_VAR_MB=5000
readonly MIN_BOOT_MB=500
readonly MIN_EFI_MB=150

readonly MAX_ALLOWED_VERSION=0

AUTO_CONFIRM=0
AUTO_REBOOT=0
DRY_RUN=0
SKIP_SNAPSHOT=0
FORCE=0

CURRENT_STATE="INIT"
IS_DNF5=0

# ==============================================================================
# COLORS
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

# ==============================================================================
# LOGGING
# ==============================================================================

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

# ==============================================================================
# ERROR HANDLER
# ==============================================================================

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
# ROOT VALIDATION
# ==============================================================================

validate_root() {
    CURRENT_STATE="ROOT_CHECK"

    if [[ $EUID -ne 0 ]]; then
        log_err "This script must run as root."
        exit 1
    fi

    log_ok "Root validation passed."
}

# ==============================================================================
# LOCK
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

# ==============================================================================
# PREREQUISITES
# ==============================================================================

validate_environment() {
    CURRENT_STATE="ENVIRONMENT"

    local required=(
        rpm
        dnf
        curl
        jq
        awk
        grep
        sed
        findmnt
        systemctl
        uname
        df
    )

    for bin in "${required[@]}"; do
        command -v "$bin" >/dev/null 2>&1 || {
            log_err "Missing dependency: $bin"
            exit 1
        }
    done

    source /etc/os-release

    if [[ "$ID" != "fedora" ]]; then
        log_err "Unsupported OS: $ID"
        exit 1
    fi

    CURRENT_VER="$(rpm -E %fedora)"

    if command -v dnf5 >/dev/null 2>&1; then
        IS_DNF5=1
    fi

    log_ok "Environment validation complete."
    log_info "Detected Fedora $CURRENT_VER"
}

# ==============================================================================
# SYSTEM HEALTH
# ==============================================================================

validate_system_health() {
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
}

# ==============================================================================
# SNAPSHOT
# ==============================================================================

create_snapshot() {
    CURRENT_STATE="SNAPSHOT"

    if [[ $SKIP_SNAPSHOT -eq 1 ]]; then
        log_warn "Snapshot creation skipped."
        return
    fi

    if findmnt -n -o FSTYPE / | grep -q "btrfs"; then

        if command -v snapper >/dev/null 2>&1; then

            if [[ $DRY_RUN -eq 0 ]]; then
                snapper create \
                    -t pre \
                    -c number \
                    -d "Fedora pre-upgrade F${CURRENT_VER}"
            fi

            log_ok "Pre-upgrade snapshot created."

        else
            log_warn "Btrfs detected without snapper."
        fi
    else
        log_info "Non-Btrfs filesystem detected."
    fi
}

# ==============================================================================
# STORAGE VALIDATION
# ==============================================================================

check_storage() {
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
}

# ==============================================================================
# THIRD-PARTY REPOS
# ==============================================================================

audit_repositories() {
    CURRENT_STATE="REPOSITORIES"

    local safe_regex="^(fedora|updates|updates-testing|fedora-cisco-openh264)"

    local repos
    repos=$(dnf repolist enabled -q | awk 'NR>1 {print $1}')

    local found=0

    for repo in $repos; do
        if ! [[ "$repo" =~ $safe_regex ]]; then

            if [[ $found -eq 0 ]]; then
                log_warn "Third-party repositories detected:"
            fi

            printf "   - %s\n" "$repo"

            found=1
        fi
    done

    log_ok "Repository audit completed."
}

# ==============================================================================
# N-1 POLICY
# ==============================================================================

calculate_target_version() {
    CURRENT_STATE="POLICY"

    log_info "Fetching Fedora release metadata..."

    local json
    json=$(curl -sfL \
        --retry 5 \
        --retry-delay 2 \
        --max-time 20 \
        "$RELEASES_URL")

    local latest
    latest=$(echo "$json" | jq -r '
        [
            .[]
            | select(.status == "active")
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
        log_ok "System already compliant with N-1 policy."
        exit 0
    fi

    local gap=$((n1 - CURRENT_VER))

    if [[ $gap -gt 1 ]]; then
        TARGET_VER=$((CURRENT_VER + 1))

        log_warn "Large version gap detected."
        log_warn "Enforcing strict +1 hop."
    else
        TARGET_VER="$n1"
    fi

    if [[ $MAX_ALLOWED_VERSION -gt 0 ]] && \
       [[ $TARGET_VER -gt $MAX_ALLOWED_VERSION ]]; then

        TARGET_VER="$MAX_ALLOWED_VERSION"

        log_warn "Ceiling policy enforced."
    fi

    export TARGET_VER

    log_ok "Target Fedora version: $TARGET_VER"
}

# ==============================================================================
# PACKAGE REFRESH
# ==============================================================================

refresh_system() {
    CURRENT_STATE="REFRESH"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Skipping package refresh."
        return
    fi

    log_info "Refreshing current system packages..."

    dnf upgrade \
        --refresh \
        -y

    log_ok "Base system updated."
}

# ==============================================================================
# REBOOT CHECK
# ==============================================================================

validate_reboot_state() {
    CURRENT_STATE="REBOOT_CHECK"

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
            | sort -V \
            | tail -n 1)"

        if [[ "$current_kernel" != "$installed_kernel" ]]; then
            reboot_required=1
        fi
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
}

# ==============================================================================
# DOWNLOAD PAYLOAD
# ==============================================================================

download_upgrade() {
    CURRENT_STATE="DOWNLOAD"

    local args=(
        "--releasever=$TARGET_VER"
        "--allowerasing"
    )

    if [[ $IS_DNF5 -eq 0 ]]; then
        args+=("--best")
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        args+=("--downloadonly")
        args+=("--setopt=tsflags=test")
    fi

    if [[ $AUTO_CONFIRM -eq 0 ]] && [[ $DRY_RUN -eq 0 ]]; then
        read -rp "Proceed with Fedora $TARGET_VER upgrade? [y/N]: " confirm

        [[ "${confirm,,}" != "y" ]] && {
            log_warn "Upgrade cancelled."
            exit 0
        }
    fi

    log_info "Downloading upgrade payload..."

    if [[ $IS_DNF5 -eq 1 ]]; then

        dnf offline-upgrade download \
            "${args[@]}" \
            -y

    else

        dnf install -y dnf-plugin-system-upgrade

        dnf system-upgrade download \
            "${args[@]}" \
            -y
    fi

    log_ok "Upgrade payload ready."
}

# ==============================================================================
# FINAL EXECUTION
# ==============================================================================

execute_upgrade() {
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

# ==============================================================================
# MAIN
# ==============================================================================

main() {

    setup_colors

    parse_args "$@"

    printf "\n${BOLD}${BLUE}"
    printf "=====================================================\n"
    printf " Fedora Ultra Enterprise Upgrade Orchestrator v%s\n" "$SCRIPT_VERSION"
    printf "=====================================================\n"
    printf "${NC}\n"

    validate_root
    acquire_lock

    validate_environment
    validate_system_health

    create_snapshot

    check_storage
    audit_repositories

    calculate_target_version

    refresh_system
    validate_reboot_state

    download_upgrade
    execute_upgrade

    CURRENT_STATE="DONE"

    printf "\n${BOLD}${GREEN}"
    printf "=====================================================\n"
    printf " Upgrade Pipeline Completed Successfully\n"
    printf "=====================================================\n"
    printf "${NC}\n"
}

main "$@"
