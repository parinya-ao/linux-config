#!/usr/bin/env bash
# ==============================================================================
# Script: docker.sh
# Purpose: Production-grade Docker installer for openSUSE
# Architecture: Modular, Open, KISS. State-validated step-by-step.
# ==============================================================================

set -eo pipefail

# ------------------------------------------------------------------------------
# 1. Globals & Configuration
# ------------------------------------------------------------------------------
LOG_FILE="/tmp/docker_install_opensuse_$(date +%s).log"
TARGET_USER="${SUDO_USER:-$USER}"

C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_RESET='\033[0m'

# ------------------------------------------------------------------------------
# 2. Logging & Monitoring Subsystem
# ------------------------------------------------------------------------------
log() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    case "$level" in
        "INFO")  echo -e "${C_BLUE}[*] [$timestamp] INFO:${C_RESET} $msg" ;;
        "OK")    echo -e "${C_GREEN}[+] [$timestamp] SUCCESS:${C_RESET} $msg" ;;
        "WARN")  echo -e "${C_YELLOW}[!] [$timestamp] WARN:${C_RESET} $msg" ;;
        "ERR")   echo -e "${C_RED}[X] [$timestamp] ERROR:${C_RESET} $msg" >&2 ;;
        "DEBUG") echo -e "${C_YELLOW}[~] [$timestamp] DEBUG:${C_RESET} $msg" ;;
    esac
}

fail_exit() {
    log "ERR" "$1"
    log "INFO" "Installation aborted. Check $LOG_FILE for details."
    exit 1
}

# ------------------------------------------------------------------------------
# 3. Validation & State Checks
# ------------------------------------------------------------------------------
check_prerequisites() {
    log "DEBUG" "Checking system prerequisites..."
    if ! command -v zypper >/dev/null 2>&1; then
        fail_exit "'zypper' package manager not found. This script requires openSUSE."
    fi
    if ! sudo -v >/dev/null 2>&1; then
        fail_exit "Current user ($TARGET_USER) does not have sudo privileges."
    fi
    log "OK" "Prerequisites verified."
}

# ------------------------------------------------------------------------------
# 4. Core Modules
# ------------------------------------------------------------------------------
install_docker_packages() {
    log "DEBUG" "Updating system repositories and installing Docker packages..."
    
    sudo zypper --non-interactive refresh 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null
    if sudo zypper --non-interactive install docker docker-compose docker-buildx 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null; then
        log "OK" "Docker packages installed successfully."
    else
        fail_exit "Failed to install Docker packages."
    fi
}

configure_and_start_service() {
    log "DEBUG" "Enabling and starting Docker service..."
    
    if sudo systemctl enable --now docker 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null; then
        log "OK" "Docker service enabled and started."
    else
        fail_exit "Failed to start Docker service."
    fi
}

configure_user_group() {
    log "DEBUG" "Configuring user permissions for: $TARGET_USER"
    
    if ! grep -q "^docker:" /etc/group; then
        sudo groupadd docker 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null || true
    fi

    if sudo usermod -aG docker "$TARGET_USER" 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null; then
        log "OK" "User $TARGET_USER added to 'docker' group."
    else
        fail_exit "Failed to add $TARGET_USER to docker group."
    fi
}

verify_installation() {
    log "DEBUG" "Verifying Docker state..."
    
    if sudo docker run --rm hello-world 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null; then
        log "OK" "Docker is fully operational. Hello-world container executed successfully."
    else
        fail_exit "Docker verification failed. Cannot run hello-world."
    fi
}

# ------------------------------------------------------------------------------
# 5. Main Orchestrator
# ------------------------------------------------------------------------------
main() {
    log "INFO" "Starting Docker installation process on openSUSE..."
    log "INFO" "Detailed logs are being written to: $LOG_FILE"
    
    check_prerequisites
    install_docker_packages
    configure_and_start_service
    configure_user_group
    verify_installation
    
    echo "======================================================================"
    log "OK" "Installation completed successfully!"
    log "INFO" "NOTE: You must log out and log back in (or run 'newgrp docker') for the group changes to take effect."
    echo "======================================================================"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
