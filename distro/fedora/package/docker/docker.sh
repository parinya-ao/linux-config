#!/usr/bin/env bash
# ==============================================================================
# Script: docker.sh
# Purpose: Production-grade Docker installer for Fedora
# Architecture: Modular, Open, KISS. State-validated step-by-step.
# ==============================================================================

# Fail fast on errors, pipeline failures, and unset variables
set -eo pipefail

# ------------------------------------------------------------------------------
# 1. Globals & Configuration
# ------------------------------------------------------------------------------
LOG_FILE="/tmp/docker_install_$(date +%s).log"
# Detect the actual user even if the script was invoked with sudo directly
TARGET_USER="${SUDO_USER:-$USER}"

# ANSI Colors
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
    
    # Write plain text to log file
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    
    # Write colored text to console
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
    
    if ! command -v dnf >/dev/null 2>&1; then
        fail_exit "'dnf' package manager not found. This script requires Fedora."
    fi

    if ! sudo -v >/dev/null 2>&1; then
        fail_exit "Current user ($TARGET_USER) does not have sudo privileges."
    fi
    
    log "OK" "Prerequisites verified."
}

# ------------------------------------------------------------------------------
# 4. Core Modules
# ------------------------------------------------------------------------------
remove_old_versions() {
    log "DEBUG" "Attempting to remove conflicting/old Docker packages..."
    
    local packages=(docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine)
    
    if sudo dnf remove -y "${packages[@]}" >> "$LOG_FILE" 2>&1; then
        log "OK" "Old versions removed or not present."
    else
        log "WARN" "Non-fatal issue removing old versions. Proceeding anyway."
    fi
}

setup_repository() {
    log "DEBUG" "Setting up Docker CE repository..."
    
    if sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo >> "$LOG_FILE" 2>&1; then
        log "OK" "Docker repository added successfully."
    else
        fail_exit "Failed to add Docker repository."
    fi
}

install_docker_packages() {
    log "DEBUG" "Installing Docker Engine, CLI, Containerd, and Plugins..."
    
    if sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y >> "$LOG_FILE" 2>&1; then
        log "OK" "Docker packages installed successfully."
    else
        fail_exit "Failed to install Docker packages."
    fi
}

configure_and_start_service() {
    log "DEBUG" "Enabling and starting Docker service..."
    
    if sudo systemctl enable --now docker >> "$LOG_FILE" 2>&1; then
        log "OK" "Docker service enabled and started."
    else
        log "WARN" "Failed to start service normally. Checking alternative iptables-nft..."
        # Fallback handling based on Fedora docs (iptables-nft issue)
        sudo alternatives --set iptables /usr/bin/iptables-nft >> "$LOG_FILE" 2>&1 || true
        if sudo systemctl restart docker >> "$LOG_FILE" 2>&1; then
            log "OK" "Docker service started using iptables-nft fallback."
        else
            fail_exit "Failed to start Docker service completely."
        fi
    fi
}

configure_user_group() {
    log "DEBUG" "Configuring user permissions for: $TARGET_USER"
    
    if grep -q "^docker:" /etc/group; then
        log "INFO" "Docker group already exists."
    else
        sudo groupadd docker >> "$LOG_FILE" 2>&1 || true
    fi

    if sudo usermod -aG docker "$TARGET_USER" >> "$LOG_FILE" 2>&1; then
        log "OK" "User $TARGET_USER added to 'docker' group."
    else
        fail_exit "Failed to add $TARGET_USER to docker group."
    fi
}

verify_installation() {
    log "DEBUG" "Verifying Docker state..."
    
    if sudo docker run --rm hello-world >> "$LOG_FILE" 2>&1; then
        log "OK" "Docker is fully operational. Hello-world container executed successfully."
    else
        fail_exit "Docker verification failed. Cannot run hello-world."
    fi
}

# ------------------------------------------------------------------------------
# 5. Main Orchestrator
# ------------------------------------------------------------------------------
main() {
    log "INFO" "Starting Docker installation process on Fedora..."
    log "INFO" "Detailed logs are being written to: $LOG_FILE"
    
    check_prerequisites
    remove_old_versions
    setup_repository
    install_docker_packages
    configure_and_start_service
    configure_user_group
    verify_installation
    
    echo "======================================================================"
    log "OK" "Installation completed successfully!"
    log "INFO" "NOTE: You must log out and log back in (or run 'newgrp docker') for the group changes to take effect."
    echo "======================================================================"
}

# If the script is executed directly (not sourced), run main.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
