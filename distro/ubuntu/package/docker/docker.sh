#!/usr/bin/env bash
# ==============================================================================
# Script: docker.sh
# Purpose: Production-grade Docker installer for Ubuntu
# Architecture: Modular, Open, KISS. State-validated step-by-step.
# ==============================================================================

set -eo pipefail

# ------------------------------------------------------------------------------
# 1. Globals & Configuration
# ------------------------------------------------------------------------------
LOG_FILE="/tmp/docker_install_ubuntu_$(date +%s).log"
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
    if ! command -v apt-get >/dev/null 2>&1; then
        fail_exit "'apt' package manager not found. This script requires Ubuntu/Debian."
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
    # As per task.md requirements
    local packages=(docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc)
    
    # We use a more careful removal to avoid "package not found" errors stopping the script
    for pkg in "${packages[@]}"; do
        sudo apt-get remove -y "$pkg" 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null || true
    done
    log "OK" "Conflicting versions audit completed."
}

setup_repository() {
    log "DEBUG" "Setting up Docker official GPG key and repository..."
    
    # Install dependencies
    sudo apt-get update -y 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null
    sudo apt-get install -y ca-certificates curl 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null

    # Setup GPG key
    sudo install -m 0755 -d /etc/apt/keyrings 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null

    # Setup Repository (DEB822 format as requested in task.md)
    # shellcheck disable=SC1091
    local codename
    codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    local arch
    arch=$(dpkg --print-architecture)

    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF >/dev/null
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $codename
Components: stable
Architectures: $arch
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt-get update -y 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null
    log "OK" "Docker repository and GPG key configured."
}

install_docker_packages() {
    log "DEBUG" "Installing Docker Engine, CLI, Containerd, and Plugins..."
    
    if sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null; then
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
    log "INFO" "Starting Docker installation process on Ubuntu..."
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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
