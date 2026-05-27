#!/usr/bin/env fish
# ==============================================================================
# Script: brave-beta.fish
# Description: Production-grade installer for Brave Browser Beta
# ==============================================================================

set -g LOG_FILE "/var/log/brave_install_debug.log"
set -g CURRENT_STATE "INIT"

# --- Logger Functions ---
function log_msg
    set -l color $argv[1]
    set -l level $argv[2]
    set -l msg $argv[3]
    set -l timestamp (date +'%Y-%m-%dT%H:%M:%S%z')
    
    set_color $color
    echo -n "[$level] "
    set_color normal
    echo "$timestamp | $msg" | tee -a $LOG_FILE
end

function log_info;    log_msg blue "INFO" $argv; end
function log_success; log_msg green "SUCCESS" $argv; end
function log_error;   log_msg red "ERROR" $argv; end
function log_debug;   log_msg yellow "DEBUG" "State: $CURRENT_STATE | $argv"; end

# --- Handlers ---
function check_root
    set CURRENT_STATE "CHECK_ROOT"
    log_debug "Checking root privileges..."
    if test (id -u) -ne 0
        log_error "Please run as root."
        exit 1
    end
    log_success "Root verified."
end

function detect_os
    set CURRENT_STATE "DETECT_OS"
    log_debug "Detecting OS..."
    if test -f /etc/os-release
        set -g OS_ID (grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
        log_debug "OS detected: $OS_ID"
    else
        log_error "Could not detect OS."
        exit 1
    end
end

function install_deps
    set CURRENT_STATE "INSTALL_DEPS"
    log_debug "Installing dnf-plugins-core..."
    if dnf install -y dnf-plugins-core >> $LOG_FILE 2>&1
        log_success "Core plugins installed."
    else
        log_error "Failed to install dependencies."
        exit 1
    end
end

function configure_repo
    set CURRENT_STATE "CONFIG_REPO"
    log_debug "Adding repo for $OS_ID..."
    set -l REPO "https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo"
    
    switch $OS_ID
        case fedora
            dnf config-manager addrepo --from-repofile=$REPO >> $LOG_FILE 2>&1
        case rhel rocky almalinux centos
            dnf config-manager --add-repo $REPO >> $LOG_FILE 2>&1
        case '*'
            log_error "Unsupported OS: $OS_ID"
            exit 1
    end
    log_success "Repository configured."
end

function install_brave
    set CURRENT_STATE "INSTALL_BRAVE"
    log_debug "Installing brave-browser-beta package..."
    if dnf install -y brave-browser-beta >> $LOG_FILE 2>&1
        log_success "Brave Beta installed."
    else
        log_error "Installation failed."
        exit 1
    end
end

function verify_install
    set CURRENT_STATE "VERIFY"
    log_debug "Checking binary..."
    if command -v brave-browser-beta >/dev/null 2>&1
        log_success "Verified: "(brave-browser-beta --version 2>/dev/null)
    else
        log_error "Verification failed."
        exit 1
    end
end

# --- Main Entry ---
function main
    touch $LOG_FILE; or begin; echo "Cannot write to log. Are you root?"; exit 1; end
    log_info "Starting Brave Setup (Fish)"
    
    check_root
    detect_os
    install_deps
    configure_repo
    install_brave
    verify_install
    
    set CURRENT_STATE "DONE"
    log_info "Setup completed cleanly."
end

main
