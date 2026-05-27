#!/usr/bin/env bash
# ==============================================================================
# Script: brave-beta.sh
# Description: Production-grade installer for Brave Browser Beta (Fedora/RHEL)
# Architecture: Modular, KISS, State-driven
# ==============================================================================

# Strict mode for safety (fail on error, undefined var, or pipe fail)
set -euo pipefail

# --- Configuration & Logging ---
LOG_FILE="/var/log/brave_install_debug.log"
CURRENT_STATE="INIT"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Logger Functions ---
log() { echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1" | tee -a "$LOG_FILE"; }
log_info() { log "${BLUE}[INFO]${NC} $1"; }
log_success() { log "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }
log_debug() { log "${YELLOW}[DEBUG] State: ${CURRENT_STATE} | $1${NC}"; }

# --- Helper Functions ---
check_root() {
    CURRENT_STATE="CHECK_ROOT"
    log_debug "Verifying root privileges..."
    if [[ "$EUID" -ne 0 ]]; then
        log_error "Please run as root or using sudo."
        exit 1
    fi
    log_success "Root privileges verified."
}

detect_os() {
    CURRENT_STATE="DETECT_OS"
    log_debug "Detecting Operating System from /etc/os-release..."
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID=$ID
        log_debug "OS detected as: $OS_ID"
    else
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
}

install_dependencies() {
    CURRENT_STATE="INSTALL_DEPS"
    log_debug "Installing dnf-plugins-core..."
    if dnf install -y dnf-plugins-core >> "$LOG_FILE" 2>&1; then
        log_success "dnf-plugins-core installed successfully."
    else
        log_error "Failed to install dnf-plugins-core. Check $LOG_FILE"
        exit 1
    fi
}

configure_repository() {
    CURRENT_STATE="CONFIG_REPO"
    log_debug "Configuring Brave Beta repository for $OS_ID..."
    
    local REPO_URL="https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo"
    
    if [[ "$OS_ID" == "fedora" ]]; then
        log_debug "Using Fedora specific command: addrepo --from-repofile"
        dnf config-manager addrepo --from-repofile="$REPO_URL" >> "$LOG_FILE" 2>&1
    elif [[ "$OS_ID" =~ ^(rhel|rocky|almalinux|centos)$ ]]; then
        log_debug "Using RHEL/Rocky specific command: --add-repo"
        dnf config-manager --add-repo "$REPO_URL" >> "$LOG_FILE" 2>&1
    else
        log_error "Unsupported OS for this script: $OS_ID"
        exit 1
    fi
    
    # Verify repo was added
    if dnf repolist | grep -qi "brave-browser-beta"; then
        log_success "Repository configured and verified."
    else
        log_error "Failed to configure repository."
        exit 1
    fi
}

install_brave_beta() {
    CURRENT_STATE="INSTALL_BRAVE"
    log_debug "Installing brave-browser-beta..."
    if dnf install -y brave-browser-beta >> "$LOG_FILE" 2>&1; then
        log_success "Brave Browser Beta installed successfully."
    else
        log_error "Installation failed. Check $LOG_FILE"
        exit 1
    fi
}

verify_installation() {
    CURRENT_STATE="VERIFY_INSTALL"
    log_debug "Verifying installation by checking brave-browser-beta version..."
    if command -v brave-browser-beta >/dev/null 2>&1; then
        local version
        version=$(brave-browser-beta --version 2>/dev/null)
        log_success "Installation fully verified! Version: $version"
    else
        log_error "Binary not found in PATH."
        exit 1
    fi
}

# --- Main Entry Point ---
main() {
    touch "$LOG_FILE" || { echo "Cannot write to log file. Run as root."; exit 1; }
    log_info "Starting Brave Browser Beta Installation"
    
    check_root
    detect_os
    install_dependencies
    configure_repository
    install_brave_beta
    verify_installation
    
    CURRENT_STATE="DONE"
    log_info "Process completed cleanly."
}

# Execute main with all arguments
main "$@"
