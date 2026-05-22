#!/usr/bin/env fish
# ==============================================================================
# Script: firefox-dev.fish
# Description: Production-grade, modular Firefox Developer Edition installer.
# OS Target: Fedora (using DNF / DNF5 package managers).
# Architecture: KISS, highly decoupled, deterministic error handling.
# ==============================================================================

# ------------------------------------------------------------------------------
# Global Settings & State Monitoring Tracker
# ------------------------------------------------------------------------------
set -g LOG_FILE "/tmp/firefox_dev_install_"(date +%s)".log"
set -g MOZ_REPO_FILE "/etc/yum.repos.d/mozilla.repo"

# ------------------------------------------------------------------------------
# Diagnostic Logging Engine
# ------------------------------------------------------------------------------
function log_state
    set -l level $argv[1]
    set -l message $argv[2]
    set -l timestamp (date "+%Y-%m-%d %H:%M:%S")

    # Record unformatted text to permanent log file
    echo "[$timestamp] [$level] $message" >> $LOG_FILE

    # Route distinct color profiles to standard streams
    switch $level
        case "INFO"
            set_color blue; echo "[*] [$timestamp] INFO: $message"; set_color normal
        case "SUCCESS"
            set_color green; echo "[+] [$timestamp] SUCCESS: $message"; set_color normal
        case "WARN"
            set_color yellow; echo "[!] [$timestamp] WARNING: $message"; set_color normal
        case "ERROR"
            # Fixed: Space removed between > and &2 to satisfy the Fish parser
            set_color red; echo "[X] [$timestamp] CRITICAL ERROR: $message" >&2; set_color normal
        case "DEBUG"
            set_color cyan; echo "[~] [$timestamp] DEBUG STATE: $message"; set_color normal
    end
end

function critical_intercept
    log_state "ERROR" $argv[1]
    log_state "INFO" "Execution halted gracefully. Diagnostics captured inside: $LOG_FILE"
    exit 1
end

# ------------------------------------------------------------------------------
# Modular Verification & Operational Units
# ------------------------------------------------------------------------------
function assert_environment
    log_state "DEBUG" "Verifying environment prerequisites..."
    
    # Assert DNF package manager exists
    if not command -v dnf >/dev/null 2>&1
        critical_intercept "Package manager 'dnf' or 'dnf5' missing. Target system is not Fedora."
    end

    # Assert passwordless or active sudo escalation path
    if not sudo -v >/dev/null 2>&1
        critical_intercept "Administrative execution failure. Non-privileged user lacks sudo clearance."
    end

    log_state "SUCCESS" "Host environment validates safely."
end

function purge_deprecated_copr
    log_state "DEBUG" "Auditing for conflicting legacy COPR dependencies..."

    # Safely look for old COPR package 'firefox-dev'
    if rpm -q firefox-dev >> $LOG_FILE 2>&1
        log_state "WARN" "Legacy community COPR installation found. Purging package 'firefox-dev'..."
        sudo dnf remove -y firefox-dev >> $LOG_FILE 2>&1
        if test $status -ne 0
            critical_intercept "Failed to uninstall legacy COPR package."
        end
        log_state "SUCCESS" "Legacy 'firefox-dev' package dropped."
    else
        log_state "DEBUG" "No legacy COPR package traces found."
    end

    # Safely disable the old repository mapping if present
    log_state "DEBUG" "Disabling 'the4runner/firefox-dev' repository if configured..."
    sudo dnf copr disable -y the4runner/firefox-dev >> $LOG_FILE 2>&1
    log_state "SUCCESS" "COPR isolation cleared cleanly."
end

function synchronize_base_metadata
    log_state "DEBUG" "Forcing structural refresh of standard DNF repository metadata..."
    sudo dnf upgrade --refresh -y --downloadonly >> $LOG_FILE 2>&1
    if test $status -ne 0
        critical_intercept "Metadata synchronization loop broke."
    end
    log_state "SUCCESS" "System metadata cache successfully synced."
end

function inject_mozilla_repository
    log_state "DEBUG" "Injecting official authenticated Mozilla RPM Repo with scoping variables..."

    # Construct clean parameters targeting exclusively 'firefox-devedition' packages via explicit priority tags
    sudo dnf config-manager addrepo \
        --id=mozilla \
        --set=baseurl=https://packages.mozilla.org/rpm/firefox \
        --set=gpgkey=https://packages.mozilla.org/rpm/firefox/signing-key.gpg \
        --set=gpgcheck=1 \
        --set=repo_gpgcheck=0 \
        --set=priority=10 \
        --set=includepkgs=firefox-devedition\* >> $LOG_FILE 2>&1

    if test $status -eq 0
        log_state "SUCCESS" "Mozilla repository metadata record mapped to $MOZ_REPO_FILE"
    else
        critical_intercept "Failed to configure secure repository mapping via dnf config-manager."
    end
end

function refresh_target_cache
    log_state "DEBUG" "Binding and checking signatures for newly attached Mozilla repo..."
    sudo dnf makecache --refresh --repo mozilla >> $LOG_FILE 2>&1
    if test $status -ne 0
        critical_intercept "Failed validation check on Mozilla signing keys."
    end
    log_state "SUCCESS" "Mozilla package index cached locally."
end

function execute_package_provisioning
    log_state "DEBUG" "Provisioning 'firefox-devedition' tracking binaries via DNF..."
    sudo dnf install -y firefox-devedition >> $LOG_FILE 2>&1
    if test $status -ne 0
        critical_intercept "Package payload transaction aborted during runtime execution."
    end
    log_state "SUCCESS" "DNF transaction finalized successfully."
end

function verify_operational_integrity
    log_state "DEBUG" "Running functional tests on runtime layer components..."

    # 1. Structural RPM database query
    if not rpm -q firefox-devedition >> $LOG_FILE 2>&1
        critical_intercept "Post-install validation fault: Package not registered in system engine database."
    end

    # 2. Binary resolution tracking path
    if not command -v firefox-devedition >/dev/null 2>&1
        critical_intercept "Post-install validation fault: Executive target command path unresolved inside path scopes."
    end
    set -l binary_path (command -v firefox-devedition)
    log_state "DEBUG" "Executable binary localized at: $binary_path"

    # 3. Dynamic runtime test
    set -l execution_version (firefox-devedition --version 2>/dev/null)
    if test -z "$execution_version"
        set execution_version "Execution Fault"
    end
    log_state "SUCCESS" "System testing complete. Verified Release Platform: $execution_version"
end

# ------------------------------------------------------------------------------
# Master Pipeline Coordinator
# ------------------------------------------------------------------------------
function main
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
end

# Execute orchestrated routine block
main
