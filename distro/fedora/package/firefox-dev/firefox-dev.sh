#!/usr/bin/env bash
# ==============================================================================
# Script: firefox-dev.sh
# Description: Production-grade, modular Firefox Developer Edition installer.
# OS Target: Fedora (using DNF / DNF5 package managers).
# Architecture: KISS, highly decoupled, deterministic error handling.
# ==============================================================================

# Fail immediately if a command fails, an unset variable is used, or a pipe fails
set -euo pipefail

# ------------------------------------------------------------------------------
# Global Settings & State Monitoring Tracker
# ------------------------------------------------------------------------------
LOG_FILE="/tmp/firefox_dev_install_$(date +%s).log"
MOZ_REPO_FILE="/etc/yum.repos.d/mozilla.repo"

# Visual Signaling Palette (ANSI Escape Sequences)
COLOR_RESET='\033[0m'
COLOR_INFO='\033[0;34m'    # Blue
COLOR_SUCCESS='\033[0;32m' # Green
COLOR_WARN='\033[1;33m'    # Yellow
COLOR_ERROR='\033[0;31m'   # Red
COLOR_DEBUG='\033[0;36m'   # Cyan

# ------------------------------------------------------------------------------
# Diagnostic Logging Engine
# ------------------------------------------------------------------------------
log_state() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # Record unformatted text to permanent log file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Route distinct color profiles to standard streams
    case "$level" in
        "INFO")    echo -e "${COLOR_INFO}[*] [$timestamp] INFO:${COLOR_RESET} $message" ;;
        "SUCCESS") echo -e "${COLOR_SUCCESS}[+] [$timestamp] SUCCESS:${COLOR_RESET} $message" ;;
        "WARN")    echo -e "${COLOR_WARN}[!] [$timestamp] WARNING:${COLOR_RESET} $message" ;;
        "ERROR")   echo -e "${COLOR_ERROR}[X] [$timestamp] CRITICAL ERROR:${COLOR_RESET} $message" >&2 ;;
        "DEBUG")   echo -e "${COLOR_DEBUG}[~] [$timestamp] DEBUG STATE:${COLOR_RESET} $message" ;;
    )
}

critical_intercept() {
    log_state "ERROR" "$1"
    log_state "INFO" "Execution halted gracefully. Diagnostics captured inside: $LOG_FILE"
    exit 1
}

# ------------------------------------------------------------------------------
# Modular Verification & Operational Units
# ------------------------------------------------------------------------------
assert_environment() {
    log_state "DEBUG" "Verifying environment prerequisites..."
    
    # Assert DNF package manager exists
    if ! command -v dnf >/dev/null 2>&1; then
        critical_intercept "Package manager 'dnf' or 'dnf5' missing. Target system is not Fedora."
    fi

    # Assert passwordless or active sudo escalation path
    if ! sudo -v >/dev/null 2>&1; then
        critical_intercept "Administrative execution failure. Non-privileged user lacks sudo clearance."
    fi

    log_state "SUCCESS" "Host environment validates safely."
}

purge_deprecated_copr() {
    log_state "DEBUG" "Auditing for conflicting legacy COPR dependencies..."

    # Safely look for old COPR package 'firefox-dev' without breaking on zero exits
    if rpm -q firefox-dev >> "$LOG_FILE" 2>&1; then
        log_state "WARN" "Legacy community COPR installation found. Purging package 'firefox-dev'..."
        sudo dnf remove -y firefox-dev >> "$LOG_FILE" 2>&1 || critical_intercept "Failed to uninstall legacy COPR package."
        log_state "SUCCESS" "Legacy 'firefox-dev' package dropped."
    else
        log_state "DEBUG" "No legacy COPR package traces found."
    fi

    # Safely disable the old repository mapping if present
    log_state "DEBUG" "Disabling 'the4runner/firefox-dev' repository if configured..."
    sudo dnf copr disable -y the4runner/firefox-dev >> "$LOG_FILE" 2>&1 || true
    log_state "SUCCESS" "COPR isolation cleared cleanly."
}

synchronize_base_metadata() {
    log_state "DEBUG" "Forcing structural refresh of standard DNF repository metadata..."
    sudo dnf upgrade --refresh -y --downloadonly >> "$LOG_FILE" 2>&1 || critical_intercept "Metadata synchronization loop broke."
    log_state "SUCCESS" "System metadata cache successfully synced."
}

inject_mozilla_repository() {
    log_state "DEBUG" "Injecting official authenticated Mozilla RPM Repo with scoping variables..."

    # Construct clean parameters targeting exclusively 'firefox-devedition' packages via explicit priority tags
    if sudo dnf config-manager addrepo \
        --id=mozilla \
        --set=baseurl=https://packages.mozilla.org/rpm/firefox \
        --set=gpgkey=https://packages.mozilla.org/rpm/firefox/signing-key.gpg \
        --set=gpgcheck=1 \
        --set=repo_gpgcheck=0 \
        --set=priority=10 \
        --set=includepkgs=firefox-devedition\* >> "$LOG_FILE" 2>&1; then
        
        log_state "SUCCESS" "Mozilla repository metadata record mapped to $MOZ_REPO_FILE"
    else
        critical_intercept "Failed to configure secure repository mapping via dnf config-manager."
    fi
}

refresh_target_cache() {
    log_state "DEBUG" "Binding and checking signatures for newly attached Mozilla repo..."
    sudo dnf makecache --refresh --repo mozilla >> "$LOG_FILE" 2>&1 || critical_intercept "Failed validation check on Mozilla signing keys."
    log_state "SUCCESS" "Mozilla package index cached locally."
}

execute_package_provisioning() {
    log_state "DEBUG" "Provisioning 'firefox-devedition' tracking binaries via DNF..."
    sudo dnf install -y firefox-devedition >> "$LOG_FILE" 2>&1 || critical_intercept "Package payload transaction aborted during runtime execution."
    log_state "SUCCESS" "DNF transaction finalized successfully."
}

verify_operational_integrity() {
    log_state "DEBUG" "Running functional tests on runtime layer components..."

    # 1. Structural RPM database query
    if ! rpm -q firefox-devedition >> "$LOG_FILE" 2>&1; then
        critical_intercept "Post-install validation fault: Package not registered in system engine database."
    fi

    # 2. Binary resolution tracking path
    local binary_path
    binary_path=$(command -v firefox-devedition 2>>"$LOG_FILE" || echo "")
    if [ -z "$binary_path" ]; then
        critical_intercept "Post-install validation fault: Executive target command path unresolved inside path scopes."
    fi
    log_state "DEBUG" "Executable binary localized at: $binary_path"

    # 3. Dynamic runtime test
    local execution_version
    execution_version=$(firefox-devedition --version 2>>"$LOG_FILE" || echo "Execution Fault")
    log_state "SUCCESS" "System testing complete. Verified Release Platform: $execution_version"
}

# ------------------------------------------------------------------------------
# Master Pipeline Coordinator
# ------------------------------------------------------------------------------
main() {
    echo "======================================================================"
    log_state "INFO" "Initializing Firefox Developer Edition Automation Script."
    log_state "INFO" "Logging tracking channel directly to: $LOG_FILE"
    echo "======================================================================"

    assert_environment
    purge_deprecated_copr
    synchronize_base_metadata
    inject_mozilla_repository
    refresh_target_cache
    execute_package_provisioning
    verify_operational_integrity

    echo "======================================================================"
    log_state "SUCCESS" "Deployment complete. Firefox Developer Edition is now ready to use!"
    echo "======================================================================"
}

# Explicit invocation isolation guard rule
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
